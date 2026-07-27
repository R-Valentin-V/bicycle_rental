CREATE OR REPLACE PACKAGE BODY pkg_booking AS

    FUNCTION calc_hours (
        p_start_time IN TIMESTAMP,
        p_end_time   IN TIMESTAMP
    ) RETURN NUMBER
    IS
        v_interval INTERVAL DAY TO SECOND;
        v_hours    NUMBER;
    BEGIN
        IF p_start_time IS NULL OR p_end_time IS NULL THEN
            RETURN NULL;
        END IF;

        IF p_end_time < p_start_time THEN
             pkg_errors.raise_error(
                 pkg_errors.c_invalid_period,
                 'Дата окончания должна быть позже даты начала'
             );
        END IF;

        v_interval := p_end_time - p_start_time;

        v_hours :=
              EXTRACT(DAY    FROM v_interval) * 24
            + EXTRACT(HOUR   FROM v_interval)
            + EXTRACT(MINUTE FROM v_interval) / 60
            + EXTRACT(SECOND FROM v_interval) / 3600;

        RETURN v_hours;
    END calc_hours;

    FUNCTION calculate_amount (
        p_bicycle_id IN bicycles.bicycle_id%TYPE,
        p_start_at   IN TIMESTAMP,
        p_end_at     IN TIMESTAMP
    ) RETURN bookings.estimated_amount%TYPE
    IS

      l_hour_rate bicycles.custom_hour_rate%TYPE;

      v_hours NUMBER;

    BEGIN

      IF p_start_at IS NULL
         OR p_end_at IS NULL
         OR p_end_at <= p_start_at
      THEN
          pkg_errors.raise_error(
              pkg_errors.c_invalid_period,
              'Дата окончания должна быть позже даты начала'
          );
      END IF;

      l_hour_rate := pkg_bicycle.get_hour_rate(p_bicycle_id);

      v_hours := calc_hours(p_start_at, p_end_at);

      RETURN ROUND(v_hours * l_hour_rate, 2);

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pkg_errors.raise_error(
              pkg_errors.c_not_found,
              'Велосипед не найден' || p_bicycle_id
          );

    END calculate_amount;

    PROCEDURE create_booking (
        p_client_id     IN clients.client_id%TYPE,
        p_bicycle_id    IN bicycles.bicycle_id%TYPE,
        p_start_at      IN TIMESTAMP,
        p_end_at        IN TIMESTAMP,
        p_hold_minutes  IN PLS_INTEGER DEFAULT 15,
        p_booking_id    OUT bookings.booking_id%TYPE
    ) IS

       l_bicycle_status       bicycles.status%TYPE;
       l_status_client        clients.status%TYPE;
       l_station_status       rental_stations.status%TYPE;
       l_amount               bookings.estimated_amount%TYPE;
       l_conflict_count       PLS_INTEGER;

    BEGIN

      IF p_start_at IS NULL
         OR p_end_at IS NULL
         OR p_end_at <= p_start_at
      THEN
          pkg_errors.raise_error(
              pkg_errors.c_invalid_period,
              'Дата окончания должна быть позже даты начала'
          );
      END IF;

      BEGIN

       SELECT status
       INTO l_status_client
       FROM clients
       WHERE client_id = p_client_id;

       IF l_status_client != 'ACTIVE' THEN
          pkg_errors.raise_error(
              pkg_errors.c_client_blocked,
              'Клиент заблокирован ' || p_client_id
          );
       END IF;

       EXCEPTION
         WHEN NO_DATA_FOUND THEN
          pkg_errors.raise_error(
              pkg_errors.c_not_found,
              'Клиент не найден ' || p_client_id
          );
      END;

      BEGIN
        SELECT status
        INTO l_station_status
        FROM rental_stations rs
        WHERE EXISTS (SELECT 1
                      FROM bicycles b
                      WHERE bicycle_id = p_bicycle_id AND
                            rs.station_id = b.station_id
                     );

        IF l_station_status != 'ACTIVE' THEN
            pkg_errors.raise_error(
                pkg_errors.c_station_closed,
                'Cтанция закрыта'
             );
        END IF;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
              pkg_errors.raise_error(
                  pkg_errors.c_not_found,
                'Велосипед не найден' || p_bicycle_id
             );
      END;
      BEGIN
           SELECT b.status
             INTO l_bicycle_status
             FROM bicycles b
            WHERE b.bicycle_id = p_bicycle_id
            FOR UPDATE;
       EXCEPTION
           WHEN NO_DATA_FOUND THEN
              pkg_errors.raise_error(
                  pkg_errors.c_not_found,
                   'Велосипед не найден: bicycle_id= ' || p_bicycle_id
               );
       END;

       IF l_bicycle_status NOT IN (
           pkg_bicycle.c_status_available,
           pkg_bicycle.c_status_reserved
       ) THEN
           pkg_errors.raise_error(
              pkg_errors.c_bicycle_unavailable,
               'Велосипед недоступен для бронирования'
           );
       END IF;


          SELECT COUNT(*)
            INTO l_conflict_count
            FROM bookings bk
           WHERE bk.bicycle_id = p_bicycle_id
             AND (
                    bk.status = c_status_confirmed
                    OR (
                        bk.status = c_status_new
                        AND bk.hold_until > SYSTIMESTAMP
                    )
                 )
             AND bk.planned_start_at < p_end_at
             AND bk.planned_end_at > p_start_at;

          IF l_conflict_count > 0 THEN
              pkg_errors.raise_error(
                  pkg_errors.c_booking_overlap,
                  'Выбранный период пересекается с существующим бронированием'
              );
          END IF;

          l_amount := calculate_amount(
              p_bicycle_id => p_bicycle_id,
              p_start_at   => p_start_at,
              p_end_at     => p_end_at
          );

          INSERT INTO bookings (
              client_id,
              bicycle_id,
              planned_start_at,
              planned_end_at,
              hold_until,
              status,
              estimated_amount,
              created_at
          )
          VALUES (
              p_client_id,
              p_bicycle_id,
              p_start_at,
              p_end_at,
              SYSTIMESTAMP + NUMTODSINTERVAL(p_hold_minutes, 'MINUTE'),
              c_status_new,
              l_amount,
              SYSTIMESTAMP
          )

          RETURNING booking_id INTO p_booking_id;


         pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'create_booking',
            p_entity_name => 'bookings',
            p_entity_id   =>  p_bicycle_id,
            p_old_data    => NULL,
            p_new_data    =>  'bookings'  || p_booking_id
        );

    END create_booking;

    PROCEDURE confirm_booking (
        p_booking_id IN bookings.booking_id%TYPE
    ) IS
        p_status    bookings.status%TYPE;
    BEGIN

      SELECT status
      INTO p_status
      FROM bookings
      WHERE booking_id = p_booking_id
      FOR UPDATE;

      IF p_status != c_status_new THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_status,
                'Статус не NEW'
            );

      END IF;

      UPDATE bookings
      SET status = c_status_confirmed
      WHERE booking_id = p_booking_id;

      pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'BICYCLE_confirm_booking',
            p_entity_name => 'bookings',
            p_entity_id   => p_booking_id,
            p_old_data    => 'status' || p_status,
            p_new_data    =>  'status'  || c_status_confirmed
        );

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pkg_errors.raise_error(
              pkg_errors.c_not_found,
            'Бронь не найдена' || p_booking_id
          );
    END confirm_booking;

    PROCEDURE cancel_booking (
        p_booking_id IN bookings.booking_id%TYPE
    )IS
        v_rental_exists  NUMBER;
        l_old_status     bookings.status%TYPE;
    BEGIN

      SELECT COUNT(*)
      INTO v_rental_exists
      FROM rentals
      WHERE booking_id = p_booking_id;

      IF v_rental_exists = 0 THEN
          pkg_errors.raise_error(
              pkg_errors.c_invalid_status,
             'Нельзя отменить бронирование с существующей арендой'
          );
      END IF;

      SELECT status
      INTO l_old_status
      FROM bookings
      WHERE booking_id = p_booking_id
      FOR UPDATE;

      UPDATE bookings
      SET status = c_status_cancelled
      WHERE booking_id = p_booking_id;

      
      pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'BICYCLE_cancel_booking',
            p_entity_name => 'bookings',
            p_entity_id   => p_booking_id,
            p_old_data    => 'status' || l_old_status,
            p_new_data    =>  'status'  || c_status_cancelled
        );

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pkg_errors.raise_error(
              pkg_errors.c_not_found,
             'Бронь не найдена' || p_booking_id
          );

    END cancel_booking;

    PROCEDURE expire_booking (
        p_booking_id IN bookings.booking_id%TYPE
    ) IS
       l_status    bookings.status%TYPE;
    BEGIN

      SELECT status
      INTO  l_status
      FROM  bookings
      WHERE booking_id = p_booking_id
      FOR UPDATE;

      UPDATE bookings
         SET status       = c_status_expired,
             cancelled_at = SYSTIMESTAMP
       WHERE booking_id = p_booking_id
         AND status = c_status_new
         AND hold_until <= SYSTIMESTAMP;

       IF SQL%ROWCOUNT = 0 THEN
          pkg_errors.raise_error(
              pkg_errors.c_rental_completed,
              'аренда уже завершена' || p_booking_id
          );
       END IF;

       EXCEPTION
         WHEN NO_DATA_FOUND THEN
          pkg_errors.raise_error(
              pkg_errors.c_not_found,
            'Бронь не найдена' || p_booking_id
          );

    END expire_booking;

    PROCEDURE expire_overdue_bookings
    IS

       CURSOR c_bookings_expire IS
          SELECT booking_id
          FROM bookings
          WHERE status = c_status_new AND
                hold_until <= SYSTIMESTAMP
          FOR UPDATE SKIP LOCKED;

       TYPE t_booking_ids IS TABLE OF bookings.booking_id%TYPE;
       l_booking_ids t_booking_ids;

       c_batch_size CONSTANT PLS_INTEGER := 100;

       e_bulk_errors EXCEPTION;
       PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);

     BEGIN

       OPEN c_bookings_expire;
       LOOP
         FETCH c_bookings_expire BULK COLLECT INTO l_booking_ids LIMIT c_batch_size;
         EXIT WHEN l_booking_ids.COUNT = 0;

         BEGIN
           FORALL i IN 1..l_booking_ids.COUNT SAVE EXCEPTIONS
              UPDATE bookings
              SET status = c_status_expired,
                  cancelled_at = SYSDATE
              WHERE booking_id = l_booking_ids(i);
           EXCEPTION
             WHEN e_bulk_errors THEN
               FOR i IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                  pkg_audit.write_error(
                  p_audit_type  => 'ERROR',
                  p_entity_id =>  l_booking_ids(
                                      SQL%BULK_EXCEPTIONS(i).ERROR_INDEX
                                  ),
                  p_action_code   => 'BOOKING_expire_overdue_bookings',
                  p_entity_name   => 'BOOKINGS',
                  p_error_code    => -SQL%BULK_EXCEPTIONS(i).ERROR_CODE,
                  p_error_message => SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE)
               );
               END LOOP;
         END;

      l_booking_ids.DELETE;
    END LOOP;

    IF c_bookings_expire%ISOPEN THEN
        CLOSE c_bookings_expire;
    END IF;

    EXCEPTION
      WHEN OTHERS THEN
        IF c_bookings_expire%ISOPEN THEN
            CLOSE c_bookings_expire;
        END IF;

        RAISE;

    END expire_overdue_bookings;

    FUNCTION can_be_started (
        p_booking_id IN bookings.booking_id%TYPE
    ) RETURN NUMBER
    IS
        l_booking_status       bookings.status%TYPE;
        l_client_status        clients.status%TYPE;
        l_bicycle_status       bicycles.status%TYPE;
        l_bicycle_id           bicycles.bicycle_id%TYPE;
        l_planned_start_at     bookings.planned_start_at%TYPE;
        l_planned_end_at       bookings.planned_end_at%TYPE;
        l_dummy                PLS_INTEGER;
    BEGIN
        BEGIN
            SELECT bk.status,
                   c.status,
                   b.status,
                   bk.bicycle_id,
                   bk.planned_start_at,
                   bk.planned_end_at
              INTO l_booking_status,
                   l_client_status,
                   l_bicycle_status,
                   l_bicycle_id,
                   l_planned_start_at,
                   l_planned_end_at
              FROM bookings bk
              JOIN clients c
                ON c.client_id = bk.client_id
              JOIN bicycles b
                ON b.bicycle_id = bk.bicycle_id
             WHERE bk.booking_id = p_booking_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Бронирование не найдено: booking_id=' || p_booking_id
                );
        END;

        IF l_booking_status != c_status_confirmed THEN
            RETURN 0;
        END IF;

        IF l_client_status != 'ACTIVE' THEN
            RETURN 0;
        END IF;

        IF l_bicycle_status NOT IN (
            pkg_bicycle.c_status_available,
            pkg_bicycle.c_status_reserved
        ) THEN
            RETURN 0;
        END IF;

        /*
         * аренду можно начать не раньше чем за 15 минут
         * и не позже чем через 30 минут после планового начала.
         */
        IF SYSTIMESTAMP <
               l_planned_start_at - NUMTODSINTERVAL(15, 'MINUTE')
           OR SYSTIMESTAMP >
               l_planned_start_at + NUMTODSINTERVAL(30, 'MINUTE')
        THEN
            RETURN 0;
        END IF;

        IF l_planned_end_at <= SYSTIMESTAMP THEN
            RETURN 0;
        END IF;

        /*
         * По бронированию уже существует аренда.
         */
        BEGIN
            SELECT 1
              INTO l_dummy
              FROM rentals r
             WHERE r.booking_id = p_booking_id
               AND ROWNUM = 1;

            RETURN 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        /*
         * У велосипеда есть другая активная аренда.
         */
        BEGIN
            SELECT 1
              INTO l_dummy
              FROM rentals r
             WHERE r.bicycle_id = l_bicycle_id
               AND r.status IN (pkg_rental.c_status_active, pkg_rental.c_status_overdue)
               AND ROWNUM = 1;

            RETURN 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        /*
         * У велосипеда активный ремонт.
         */
        BEGIN
            SELECT 1
              INTO l_dummy
              FROM repair_orders ro
             WHERE ro.bicycle_id = l_bicycle_id
               AND ro.status IN (pkg_repair.c_status_open, pkg_repair.c_status_in_progress)
               AND ROWNUM = 1;

            RETURN 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        RETURN 1;
    END can_be_started;
END pkg_booking;
