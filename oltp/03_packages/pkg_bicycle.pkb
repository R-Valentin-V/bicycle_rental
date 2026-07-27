CREATE OR REPLACE PACKAGE BODY pkg_bicycle AS

    FUNCTION get_status (
        p_bicycle_id IN bicycles.bicycle_id%TYPE
    ) RETURN bicycles.status%TYPE IS

       l_status   bicycles.status%TYPE;

    BEGIN

      SELECT status
      INTO l_status
      FROM bicycles
      WHERE bicycle_id = p_bicycle_id;

      RETURN l_status;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pkg_errors.raise_error(
              pkg_errors.c_not_found,
              'Велосипед не найден: bicycle_id=' || p_bicycle_id
          );
    END get_status;

    FUNCTION get_hour_rate (
        p_bicycle_id IN bicycles.bicycle_id%TYPE
    ) RETURN bicycles.custom_hour_rate%TYPE
    IS
        l_hour_rate bicycles.custom_hour_rate%TYPE;
    BEGIN
        SELECT COALESCE(
                   b.custom_hour_rate,
                   bm.default_hour_rate
               )
          INTO l_hour_rate
          FROM bicycles b
          JOIN bicycle_models bm
            ON bm.model_id = b.model_id
         WHERE b.bicycle_id = p_bicycle_id;

        RETURN l_hour_rate;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Велосипед не найден: bicycle_id=' || p_bicycle_id
            );
    END get_hour_rate;

    FUNCTION is_available (
        p_bicycle_id         IN bicycles.bicycle_id%TYPE,
        p_start_at           IN TIMESTAMP,
        p_end_at             IN TIMESTAMP,
        p_exclude_booking_id IN bookings.booking_id%TYPE,
        p_exclude_rental_id  IN rentals.rental_id%TYPE
    ) RETURN NUMBER
    IS
        l_status bicycles.status%TYPE;
        l_dummy  PLS_INTEGER;

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
            SELECT b.status
              INTO l_status
              FROM bicycles b
             WHERE b.bicycle_id = p_bicycle_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Велосипед не найден: bicycle_id=' || p_bicycle_id
                );
        END;

        IF l_status NOT IN (
            c_status_available,
            c_status_reserved
        ) THEN
            RETURN 0;
        END IF;

        /*
         * Конфликт бронирований.
         */
        BEGIN
            SELECT 1
              INTO l_dummy
              FROM bookings bk
             WHERE bk.bicycle_id = p_bicycle_id
               AND bk.status IN (
                    pkg_booking.c_status_new,
                    pkg_booking.c_status_confirmed
               )
               AND bk.planned_start_at < p_end_at
               AND bk.planned_end_at > p_start_at
               AND (
                    p_exclude_booking_id IS NULL
                    OR bk.booking_id <> p_exclude_booking_id
               )
               AND ROWNUM = 1;

            RETURN 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        /*
         * Конфликт аренды.
         */
        BEGIN
            SELECT 1
              INTO l_dummy
              FROM rentals r
             WHERE r.bicycle_id = p_bicycle_id
               AND r.status IN (
                    pkg_rental.c_status_active,
                    pkg_rental.c_status_overdue
               )
               AND r.actual_start_at < p_end_at
               AND (
                  p_exclude_rental_id IS NULL
                  OR r.rental_id <> p_exclude_rental_id
               )
               AND NVL(
                       r.actual_end_at,
                       r.planned_end_at
                   ) > p_start_at
               AND ROWNUM = 1;

            RETURN 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        /*
         * Активный ремонт.
         */
        BEGIN
            SELECT 1
              INTO l_dummy
              FROM repair_orders ro
             WHERE ro.bicycle_id = p_bicycle_id
               AND ro.status IN (
                    pkg_repair.c_status_open,
                    pkg_repair.c_status_in_progress
               )
               AND ROWNUM = 1;

            RETURN 0;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        RETURN 1;
    END is_available;

    PROCEDURE change_status (
        p_bicycle_id  IN bicycles.bicycle_id%TYPE,
        p_new_status  IN bicycles.status%TYPE,
        p_reason      IN bicycle_status_history.change_reason%TYPE,
        p_staff_id    IN staff.staff_id%TYPE,
        p_source_type IN bicycle_status_history.source_type%TYPE,
        p_source_id   IN bicycle_status_history.source_id%TYPE
    ) IS
        l_old_status bicycles.status%TYPE;
    BEGIN
        IF p_new_status IS NULL
           OR p_new_status NOT IN (
                c_status_available,
                c_status_reserved,
                c_status_rented,
                c_status_repair,
                c_status_blocked,
                c_status_retired
           )
        THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_status,
                'Недопустимый статус велосипеда: ' || p_new_status
            );
        END IF;

        IF TRIM(p_reason) IS NULL THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_status,
                'Причина изменения статуса обязательна'
            );
        END IF;

        BEGIN
            SELECT b.status
              INTO l_old_status
              FROM bicycles b
             WHERE b.bicycle_id = p_bicycle_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Велосипед не найден: bicycle_id=' || p_bicycle_id
                );
        END;

        IF l_old_status = p_new_status THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_status,
                'Велосипед уже имеет статус ' || p_new_status
            );
        END IF;


        UPDATE bicycles
           SET status = p_new_status
         WHERE bicycle_id = p_bicycle_id;

        INSERT INTO bicycle_status_history (
            bicycle_id,
            old_status,
            new_status,
            change_reason,
            changed_by_staff_id,
            changed_at,
            source_type,
            source_id
        )
        VALUES (
            p_bicycle_id,
            l_old_status,
            p_new_status,
            p_reason,
            p_staff_id,
            SYSTIMESTAMP,
            p_source_type,
            p_source_id
        );

        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'BICYCLE_STATUS_CHANGED',
            p_entity_name => 'BICYCLES',
            p_entity_id   => p_bicycle_id,
            p_old_data    =>  'status ' || l_old_status,
            p_new_data    =>  'status'  || p_new_status
        );
    END change_status;

    PROCEDURE move_to_station (
        p_bicycle_id IN bicycles.bicycle_id%TYPE,
        p_station_id IN rental_stations.station_id%TYPE,
        p_staff_id   IN staff.staff_id%TYPE,
        p_reason     IN VARCHAR2
    ) IS
        l_old_station    bicycles.station_id%TYPE;
        l_station_status rental_stations.status%TYPE;
    BEGIN
        IF p_bicycle_id IS NULL THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Не указан bicycle_id'
            );
        END IF;

        IF p_station_id IS NULL THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Не указан station_id'
            );
        END IF;

        BEGIN
            SELECT rs.status
              INTO l_station_status
              FROM rental_stations rs
             WHERE rs.station_id = p_station_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Станция не найдена: station_id=' || p_station_id
                );
        END;

        IF l_station_status <> 'ACTIVE' THEN
            pkg_errors.raise_error(
                pkg_errors.c_station_closed,
                'Станция недоступна для приёма велосипеда: station_id='
                || p_station_id
            );
        END IF;

        BEGIN
            SELECT b.station_id
              INTO l_old_station
              FROM bicycles b
             WHERE b.bicycle_id = p_bicycle_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Велосипед не найден: bicycle_id=' || p_bicycle_id
                );
        END;

        IF l_old_station = p_station_id THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_status,
                'Велосипед уже находится на станции: station_id='
                || p_station_id
            );
        END IF;

        UPDATE bicycles
           SET station_id = p_station_id
         WHERE bicycle_id = p_bicycle_id;

        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'BICYCLE_MOVED_TO_STATION',
            p_entity_name => 'BICYCLES',
            p_entity_id   => p_bicycle_id,
            p_old_data    =>  'station_id ' || l_old_station,
            p_new_data    =>  'station_id'  || p_station_id
        );
    END move_to_station;
        
    PROCEDURE check_maintenance_due (
        p_service_interval_days IN PLS_INTEGER
    ) IS
       CURSOR c_bicycles IS 
              SELECT
                b.bicycle_id
            FROM bicycles b
            WHERE NVL(
                      b.last_service_date,
                      b.purchase_date
                  ) < TRUNC(SYSDATE) - p_service_interval_days
              AND b.status NOT IN (
                    c_status_blocked,
                    c_status_repair,
                    c_status_retired,
                    c_status_rented
                  )
              AND NOT EXISTS (
                    SELECT 1
                    FROM repair_orders ro
                    WHERE ro.bicycle_id = b.bicycle_id
                      AND ro.status IN (
                            'OPEN',
                            'DIAGNOSIS',
                            'IN_PROGRESS',
                            'WAITING_PARTS'
                          )
                  )
            FOR UPDATE OF b.status SKIP LOCKED;
            
    BEGIN
        IF p_service_interval_days IS NULL
           OR p_service_interval_days <= 0
        THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_period,
                'Интервал технического обслуживания должен быть больше нуля'
            );
        END IF;

        FOR bicycle_rec IN c_bicycles LOOP
          change_status(
              p_bicycle_id  => bicycle_rec.bicycle_id,
              p_new_status  => c_status_blocked,
              p_reason      => 'Превышен интервал технического обслуживания: '
                               || p_service_interval_days || ' дней',
              p_staff_id    => NULL,
              p_source_type => 'SCHEDULER_JOB',
              p_source_id   => NULL
          );
        END LOOP;
    END check_maintenance_due;

END pkg_bicycle;
