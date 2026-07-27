CREATE OR REPLACE PACKAGE BODY pkg_rental AS

    PROCEDURE start_from_booking (
        p_booking_id       IN  bookings.booking_id%TYPE,
        p_start_station_id IN  rental_stations.station_id%TYPE,
        p_staff_id         IN  staff.staff_id%TYPE,
        p_rental_id        OUT rentals.rental_id%TYPE
    ) IS
        i_bicycle_id      bookings.bicycle_id%TYPE;
        i_client_id       bookings.client_id%TYPE;
        l_planned_end_at  bookings.planned_end_at%TYPE;
        l_base_amount     bookings.estimated_amount%TYPE;
    BEGIN
        SELECT client_id,
               bicycle_id,
               planned_end_at,
               estimated_amount
        INTO   i_client_id,
               i_bicycle_id,
               l_planned_end_at,
               l_base_amount
        FROM bookings
        WHERE booking_id = p_booking_id
        FOR UPDATE;

        INSERT INTO rentals (
            booking_id,
            client_id,
            bicycle_id,
            start_station_id,
            planned_end_at,
            actual_start_at,
            status,
            base_amount,
            created_at
        )
        VALUES (
            p_booking_id,
            i_client_id,
            i_bicycle_id,
            p_start_station_id,
            l_planned_end_at,
            SYSTIMESTAMP,
            c_status_active,
            l_base_amount,
            SYSTIMESTAMP
        )
        RETURNING rental_id
        INTO p_rental_id;

        UPDATE bookings
        SET status = c_status_completed
        WHERE booking_id = p_booking_id;

        UPDATE bicycles
        SET status = pkg_bicycle.c_status_rented
        WHERE bicycle_id = i_bicycle_id;


        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'BOOKING_start_from_booking',
            p_entity_name => 'BOOKINGS',
            p_entity_id   => p_booking_id,
            p_old_data    => NULL,
            p_new_data    =>  'status ' || p_start_station_id
        );


        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Бронирование не найдено: ' || p_booking_id
                );
    END start_from_booking;

    PROCEDURE start_without_booking (
        p_client_id        IN clients.client_id%TYPE,
        p_bicycle_id       IN bicycles.bicycle_id%TYPE,
        p_start_station_id IN rental_stations.station_id%TYPE,
        p_planned_end_at   IN TIMESTAMP,
        p_staff_id         IN staff.staff_id%TYPE,
        p_rental_id        OUT rentals.rental_id%TYPE
    ) IS

       l_amount rentals.base_amount%TYPE;

    BEGIN

        l_amount := pkg_booking.calculate_amount(
              p_bicycle_id => p_bicycle_id,
              p_start_at   => SYSTIMESTAMP,
              p_end_at     => p_planned_end_at
        );

        INSERT INTO rentals (
                  booking_id,
                  client_id,
                  bicycle_id,
                  start_station_id,
                  planned_end_at,
                  actual_start_at,
                  status,
                  base_amount,
                  created_at
              )
              VALUES (
                  NULL,
                  p_client_id,
                  p_bicycle_id,
                  p_start_station_id,
                  p_planned_end_at,
                  SYSTIMESTAMP,
                  c_status_active,
                  l_amount,
                  SYSTIMESTAMP
              )
              RETURNING rental_id
              INTO p_rental_id;

              IF p_rental_id IS NULL THEN
                pkg_errors.raise_error(
                    pkg_errors.c_rental_not_created,
                    'Аренда не созданна'
                );
              END IF;


              UPDATE bicycles
              SET status = pkg_bicycle.c_status_rented
              WHERE bicycle_id = p_bicycle_id;
              
              
              pkg_audit.write_event(
                  p_audit_type  => 'EVENT',
                  p_action_code => 'rentals_start_without_booking',
                  p_entity_name => 'rentals',
                  p_entity_id   => p_rental_id,
                  p_old_data    => NULL,
                  p_new_data    =>  'status'  || p_start_station_id
              );
    END start_without_booking;

    FUNCTION calculate_extension_amount (
        p_rental_id    IN rentals.rental_id%TYPE,
        p_new_end_at   IN TIMESTAMP
    ) RETURN NUMBER
    IS
     l_bicycle_id       rentals.bicycle_id%TYPE;
     l_extension_amount rentals.extension_amount%TYPE;
     l_date_start       rentals.planned_end_at%TYPE;
    BEGIN
        SELECT bicycle_id,
               planned_end_at
        INTO   l_bicycle_id,
               l_date_start
        FROM rentals
        WHERE rental_id = p_rental_id;

        l_extension_amount := pkg_booking.calculate_amount(
              p_bicycle_id => l_bicycle_id,
              p_start_at   => l_date_start,
              p_end_at     => p_new_end_at
        );



        RETURN l_extension_amount;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
              pkg_errors.raise_error(
                  pkg_errors.c_not_found,
                  'Аренда не найдена' || p_rental_id
              );

    END calculate_extension_amount;

    PROCEDURE extend_rental (
        p_rental_id   IN rentals.rental_id%TYPE,
        p_new_end_at  IN TIMESTAMP,
        p_extension_id OUT rental_extensions.extension_id%TYPE
    )IS

       l_end_at            rentals.planned_end_at%TYPE;
       l_bicycle_id        rentals.bicycle_id%TYPE;
       l_permittedt        NUMBER;
       l_extension_amount  rentals.extension_amount%TYPE;
    BEGIN

      SELECT planned_end_at,
             bicycle_id
      INTO   l_end_at,
             l_bicycle_id
      FROM rentals
      WHERE rental_id = p_rental_id
      FOR UPDATE;

      l_permittedt := pkg_bicycle.is_available(l_bicycle_id, l_end_at, p_new_end_at, NULL, p_rental_id);

      IF l_permittedt = 0 THEN
        pkg_errors.raise_error(
            pkg_errors.c_extension_not_allowed,
            'Продление невозможно' || p_rental_id
        );
      END IF;

      l_extension_amount := calculate_extension_amount(p_rental_id, p_new_end_at);

      UPDATE rentals
      SET planned_end_at = p_new_end_at,
          updated_at = SYSTIMESTAMP
      WHERE rental_id = p_rental_id;



      INSERT INTO rental_extensions(rental_id, old_end_at, new_end_at, amount, status, created_at)
      VALUES(p_rental_id, l_end_at, p_new_end_at, l_extension_amount, 'CREATED', SYSTIMESTAMP)
      RETURNING extension_id INTO p_extension_id;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
           pkg_errors.raise_error(
               pkg_errors.c_not_found,
               'Аренда не найдена' || p_rental_id
           );
    END extend_rental;

    FUNCTION calculate_penalty (
        p_rental_id IN rentals.rental_id%TYPE,
        p_as_of     IN TIMESTAMP
    ) RETURN NUMBER
    IS
        c_penalty_multiplier CONSTANT NUMBER := 2;

        l_bicycle_id       rentals.bicycle_id%TYPE;
        l_status           rentals.status%TYPE;
        l_planned_end_at   rentals.planned_end_at%TYPE;
        l_actual_end_at    rentals.actual_end_at%TYPE;
        l_calculation_at   TIMESTAMP;
        l_overdue_hours    NUMBER;
        l_hour_rate        bicycles.custom_hour_rate%TYPE;
        l_penalty          rentals.penalty_amount%TYPE;
    BEGIN
        IF p_as_of IS NULL THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_period,
                'Дата расчёта штрафа не указана'
            );
        END IF;

        BEGIN
            SELECT r.bicycle_id,
                   r.status,
                   r.planned_end_at,
                   r.actual_end_at
              INTO l_bicycle_id,
                   l_status,
                   l_planned_end_at,
                   l_actual_end_at
              FROM rentals r
             WHERE r.rental_id = p_rental_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Аренда не найдена: rental_id=' || p_rental_id
                );
        END;


        IF l_status = c_status_cancelled THEN
            RETURN 0;
        END IF;

        l_calculation_at :=
            CASE
                WHEN l_actual_end_at IS NULL THEN
                    p_as_of
                WHEN p_as_of < l_actual_end_at THEN
                    p_as_of
                ELSE
                    l_actual_end_at
            END;

        IF l_calculation_at <= l_planned_end_at THEN
            RETURN 0;
        END IF;

        l_hour_rate := pkg_bicycle.get_hour_rate(l_bicycle_id);

        l_overdue_hours := pkg_booking.calc_hours(l_planned_end_at, l_calculation_at);

        l_penalty := ROUND(
            l_overdue_hours
            * l_hour_rate
            * c_penalty_multiplier,
            2
        );

        RETURN l_penalty;
    END calculate_penalty;

    PROCEDURE finish_rental (
        p_rental_id      IN rentals.rental_id%TYPE,
        p_end_station_id IN rental_stations.station_id%TYPE,
        p_staff_id       IN staff.staff_id%TYPE,
        p_actual_end_at  IN TIMESTAMP
    ) IS
       l_total_amount   rentals.total_amount%TYPE;
       l_bicycle_id     rentals.bicycle_id%TYPE;
       l_r_station_id   rentals.start_station_id%TYPE;
    BEGIN

        SELECT base_amount + NVL(extension_amount, 0) + NVL(penalty_amount, 0),
               bicycle_id,
               start_station_id
        INTO l_total_amount,
             l_bicycle_id,
             l_r_station_id
        FROM rentals
        WHERE rental_id = p_rental_id;


        UPDATE rentals
        SET end_station_id = p_end_station_id,
            actual_end_at  = p_actual_end_at,
            total_amount   = l_total_amount,
            updated_at     = SYSTIMESTAMP,
            status = c_status_completed
        WHERE rental_id = p_rental_id;

        pkg_bicycle.change_status(
              l_bicycle_id,
              pkg_bicycle.c_status_available,
              'finish_rental',
              p_staff_id,
              'RENTAL',
              'finish_rental'
         );

        IF l_r_station_id != p_end_station_id  THEN
           pkg_bicycle.move_to_station(
             l_bicycle_id,
             p_end_station_id,
             p_staff_id,
             'finish_rental'
            );
        END IF;

    END finish_rental;

    PROCEDURE mark_overdue_rentals
    IS
       CURSOR c_rentals IS
          SELECT rental_id
          FROM rentals
          WHERE status = c_status_active AND
                planned_end_at <= SYSTIMESTAMP
          FOR UPDATE SKIP LOCKED;

       TYPE t_rental_id IS TABLE OF rentals.rental_id%TYPE;

       l_rental_id      t_rental_id;
       c_batch_size     CONSTANT PLS_INTEGER := 100;

       e_bulk_errors EXCEPTION;
       PRAGMA EXCEPTION_INIT(e_bulk_errors, -24381);
    BEGIN
        OPEN c_rentals;
        LOOP
          FETCH c_rentals BULK COLLECT INTO l_rental_id LIMIT c_batch_size;
          EXIT WHEN l_rental_id.COUNT = 0;

          BEGIN
              FORALL i IN 1..l_rental_id.COUNT SAVE EXCEPTIONS
                 UPDATE rentals
                 SET status = c_status_overdue
                 WHERE rental_id = l_rental_id(i);

              EXCEPTION
                WHEN e_bulk_errors THEN
                   FOR i IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
                       pkg_audit.write_error(
                          p_audit_type  => 'ERROR',
                          p_entity_id =>  l_rental_id(
                                              SQL%BULK_EXCEPTIONS(i).ERROR_INDEX
                                          ),
                          p_action_code   => 'RENTAL_OVERDUE_FAILED',
                          p_entity_name   => 'rentals',
                          p_error_code    => -SQL%BULK_EXCEPTIONS(i).ERROR_CODE,
                          p_error_message => SQLERRM(-SQL%BULK_EXCEPTIONS(i).ERROR_CODE)
                       );
                   END LOOP;
          END;

          l_rental_id.DELETE;
        END LOOP;

        IF c_rentals%ISOPEN THEN
          CLOSE c_rentals;
        END IF;

        EXCEPTION
          WHEN OTHERS THEN
            IF c_rentals%ISOPEN THEN
               CLOSE c_rentals;
            END IF;
            RAISE;
    END mark_overdue_rentals;

    FUNCTION get_outstanding_amount (
        p_rental_id IN rentals.rental_id%TYPE
    ) RETURN NUMBER
    IS
      l_total_amount  rentals.total_amount%TYPE;
      l_paid_amount   payments.amount%TYPE;
    BEGIN

      SELECT total_amount
      INTO   l_total_amount
      FROM rentals
      WHERE rental_id = p_rental_id;

      l_paid_amount := pkg_payment.get_success_amount(p_rental_id);

      RETURN GREATEST(l_total_amount - l_paid_amount, 0);

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          pkg_errors.raise_error(
              pkg_errors.c_not_found,
              'Аренда не найденна' || p_rental_id
          );
    END get_outstanding_amount;

END pkg_rental;
