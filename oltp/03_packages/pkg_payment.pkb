CREATE OR REPLACE PACKAGE BODY pkg_payment AS

    PROCEDURE create_payment(
        p_client_id       IN clients.client_id%TYPE,
        p_rental_id       IN rentals.rental_id%TYPE DEFAULT NULL,
        p_booking_id      IN bookings.booking_id%TYPE DEFAULT NULL,
        p_payment_type    IN payments.payment_type%TYPE,
        p_amount          IN payments.amount%TYPE,
        p_payment_method  IN payments.payment_method%TYPE,
        p_idempotency_key IN payments.idempotency_key%TYPE,
        p_payment_id      OUT payments.payment_id%TYPE
    ) IS
    BEGIN

        p_payment_id := NULL;

        IF p_client_id IS NULL THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_period,
                'Не указан клиент'
            );
        END IF;

        IF p_amount IS NULL OR p_amount <= 0 THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_period,
                'Сумма платежа должна быть больше нуля'
            );
        END IF;

        IF p_payment_type NOT IN (
            c_type_booking,
            c_type_rental,
            c_type_extension,
            c_type_penalty
        ) THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_status,
                'Недопустимый тип платежа: ' || p_payment_type
            );
        END IF;

        BEGIN
            SELECT payment_id
            INTO p_payment_id
            FROM payments
            WHERE idempotency_key = p_idempotency_key AND
                  client_id       = p_client_id;

            RETURN;

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;
        IF p_rental_id IS NULL AND p_booking_id IS NULL THEN
          pkg_errors.raise_error(
              pkg_errors.c_payment_source_missing,
              'p_rental_id и p_booking_id пусты'
          );
        ELSIF  p_booking_id IS NOT NULL THEN

          INSERT INTO payments(
                 booking_id,
                 client_id,
                 payment_type,
                 status,
                 amount,
                 payment_method,
                 idempotency_key,
                 created_at)
          VALUES (
                 p_booking_id,
                 p_client_id,
                 p_payment_type,
                 c_status_created,
                 p_amount,
                 p_payment_method,
                 p_idempotency_key,
                 SYSTIMESTAMP)
          RETURNING payment_id
          INTO p_payment_id;

        ELSIF p_rental_id IS NOT NULL THEN

          INSERT INTO payments(
                 rental_id,
                 client_id,
                 payment_type,
                 status,
                 amount,
                 payment_method,
                 idempotency_key,
                 created_at)
          VALUES (
                 p_rental_id,
                 p_client_id,
                 p_payment_type,
                 c_status_created,
                 p_amount,
                 p_payment_method,
                 p_idempotency_key,
                 SYSTIMESTAMP)
          RETURNING payment_id
          INTO p_payment_id;

        END IF;

        IF SQL%ROWCOUNT = 0 THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_not_created,
                'Платеж не записался в БД'
            );
        END IF;
        
        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'PAYMENT_CREATED',
            p_entity_name => 'PAYMENTS',
            p_entity_id   => p_payment_id,
            p_old_data    => NULL,
            p_new_data    =>  'rental_id ' || p_rental_id
        );

        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                SELECT payment_id
                  INTO p_payment_id
                  FROM payments
                 WHERE idempotency_key = p_idempotency_key;
    END create_payment;

    PROCEDURE mark_pending (
        p_payment_id IN payments.payment_id%TYPE,
        p_external_payment_id IN payments.external_payment_id%TYPE
    ) IS
       l_old_status   payments.status%TYPE;
    BEGIN

        SELECT status
        INTO l_old_status
        FROM payments
        WHERE payment_id = p_payment_id
        FOR UPDATE;

        UPDATE payments
        SET external_payment_id = COALESCE(p_external_payment_id, external_payment_id),
            status = c_status_pending
        WHERE payment_id = p_payment_id;

        IF SQL%ROWCOUNT = 0 THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_not_success,
                'Платёж не переведен  в статус' || c_status_pending
            );
        END IF;

        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'PAYMENT_SUCCEEDED',
            p_entity_name => 'PAYMENTS',
            p_entity_id   => p_payment_id,
            p_old_data    => 'status ' || l_old_status,
            p_new_data    =>  'status ' || c_status_pending
        );


    END mark_pending;

    PROCEDURE mark_success (
        p_payment_id IN payments.payment_id%TYPE,
        p_external_payment_id IN payments.external_payment_id%TYPE,
        p_paid_at    IN TIMESTAMP
    ) IS
       l_status   payments.status%TYPE;
    BEGIN
        SELECT status
        INTO   l_status
        FROM payments
        WHERE payment_id = p_payment_id
        FOR UPDATE;

        UPDATE payments
        SET external_payment_id = p_external_payment_id,
            status              = c_status_success,
            paid_at             = p_paid_at
        WHERE payment_id = p_payment_id;

        IF SQL%ROWCOUNT = 0 THEN

            pkg_errors.raise_error(
                pkg_errors.c_payment_not_success,
                'Платёж не переведен  в статус' || c_status_success
            );

        END IF;

        
        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'payments_mark_pending',
            p_entity_name => 'PAYMENTS',
            p_entity_id   => p_payment_id,
            p_old_data    => 'status ' || l_status,
            p_new_data    =>  'status ' || c_status_success
        );

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Платеж не найден' || p_payment_id
            );
    END mark_success;

    PROCEDURE mark_failed (
        p_payment_id     IN payments.payment_id%TYPE,
        p_failure_reason IN payments.failure_reason%TYPE,
        p_error_code     IN NUMBER ,
        p_failed_at      IN TIMESTAMP
    ) IS
       l_status   payments.status%TYPE;
    BEGIN
        SELECT status
        INTO   l_status
        FROM   payments
        WHERE  payment_id = p_payment_id
        FOR UPDATE;

        UPDATE payments
        SET status         = c_status_failed,
            failed_at      = p_failed_at,
            failure_reason = p_failure_reason
        WHERE payment_id = p_payment_id;

        IF SQL%ROWCOUNT = 0 THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_not_failed,
                'Платёж не переведен  в статус' || c_status_failed
            );
        END IF;

        
        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'payments_mark_failed',
            p_entity_name => 'PAYMENTS',
            p_entity_id   => p_payment_id,
            p_old_data    => 'status ' || l_status,
            p_new_data    =>  'status ' || c_status_failed
        );
        
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Платеж не найден' || p_payment_id
            );
    END mark_failed;

    PROCEDURE create_refund (
        p_source_payment_id IN payments.payment_id%TYPE,
        p_amount            IN payments.amount%TYPE,
        p_idempotency_key   IN payments.idempotency_key%TYPE,
        p_refund_payment_id OUT payments.payment_id%TYPE
    ) IS
        l_source_status      payments.status%TYPE;
        l_source_type        payments.payment_type%TYPE;
        l_source_amount      payments.amount%TYPE;
        l_client_id          payments.client_id%TYPE;
        l_rental_id          payments.rental_id%TYPE;
        l_booking_id         payments.booking_id%TYPE;
        l_currency           payments.currency_code%TYPE;
        l_payment_method     payments.payment_method%TYPE;
        l_refunded_amount    payments.amount%TYPE;
    BEGIN
        p_refund_payment_id := NULL;

        IF p_amount IS NULL OR p_amount <= 0 THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_insufficient,
                'Сумма возврата должна быть больше нуля'
            );
        END IF;

        IF p_idempotency_key IS NULL THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Не указан ключ идемпотентности'
            );
        END IF;

        BEGIN
            SELECT p.payment_id
              INTO p_refund_payment_id
              FROM payments p
             WHERE p.idempotency_key = p_idempotency_key;

            RETURN;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;


        BEGIN
            SELECT p.status,
                   p.payment_type,
                   p.amount,
                   p.client_id,
                   p.rental_id,
                   p.booking_id,
                   p.currency_code,
                   p.payment_method
              INTO l_source_status,
                   l_source_type,
                   l_source_amount,
                   l_client_id,
                   l_rental_id,
                   l_booking_id,
                   l_currency,
                   l_payment_method
              FROM payments p
             WHERE p.payment_id = p_source_payment_id
             FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Исходный платёж не найден: payment_id='
                    || p_source_payment_id
                );
        END;

        IF l_source_status != c_status_success THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_not_created,
                'Возврат разрешён только для успешного платежа'
            );
        END IF;

        IF l_source_type = c_type_refund THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_insufficient,
                'Нельзя создать возврат по операции возврата'
            );
        END IF;

        SELECT NVL(SUM(p.amount), 0)
          INTO l_refunded_amount
          FROM payments p
         WHERE p.external_payment_id = p_source_payment_id
           AND p.payment_type = c_type_refund
           AND p.status IN (
               c_status_created,
               c_status_pending,
               c_status_success
           );

        IF l_refunded_amount + p_amount > l_source_amount THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_insufficient,
                'Сумма возврата превышает доступный остаток. '
                || 'Платёж: ' || l_source_amount
                || ', уже возвращается или возвращено: '
                || l_refunded_amount
            );
        END IF;

        INSERT INTO payments (
            external_payment_id,
            client_id,
            rental_id,
            booking_id,
            payment_type,
            amount,
            currency_code,
            payment_method,
            status,
            idempotency_key,
            created_at
        )
        VALUES (
            p_source_payment_id,
            l_client_id,
            l_rental_id,
            l_booking_id,
            c_type_refund,
            p_amount,
            l_currency,
            l_payment_method,
            c_status_created,
            p_idempotency_key,
            SYSTIMESTAMP
        )
        RETURNING payment_id INTO p_refund_payment_id;


        
        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'REFUND_CREATED',
            p_entity_name => 'PAYMENTS',
            p_entity_id   => p_refund_payment_id,
            p_old_data    => NULL,
            p_new_data    =>  'status ' || p_source_payment_id
        );
        
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            SELECT p.payment_id
              INTO p_refund_payment_id
              FROM payments p
             WHERE p.idempotency_key = p_idempotency_key;
    END create_refund;

    FUNCTION get_success_amount (
        p_rental_id IN rentals.rental_id%TYPE
    ) RETURN NUMBER
    IS
       l_dummy  PLS_INTEGER;
       l_summ   payments.amount%TYPE;
    BEGIN

        BEGIN
            SELECT 1
              INTO l_dummy
              FROM rentals r
             WHERE r.rental_id = p_rental_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                pkg_errors.raise_error(
                    pkg_errors.c_not_found,
                    'Аренда не найдена: rental_id=' || p_rental_id
                );
        END;

        SELECT NVL(SUM(amount), 0)
        INTO l_summ
        FROM payments
        WHERE rental_id = p_rental_id AND 
              status    = c_status_success;

        RETURN l_summ;

    END get_success_amount;

    FUNCTION is_paid (
        p_rental_id       IN rentals.rental_id%TYPE,
        p_required_amount IN NUMBER
    ) RETURN NUMBER
    IS
        l_actual_amount payments.amount%TYPE;
    BEGIN
        IF p_required_amount IS NULL OR p_required_amount < 0 THEN
            pkg_errors.raise_error(
                pkg_errors.c_payment_insufficient,
                'Требуемая сумма не может быть отрицательной'
            );
        END IF;

        l_actual_amount := get_success_amount(p_rental_id);

        IF l_actual_amount >= p_required_amount THEN
            RETURN 1;
        END IF;

        RETURN 0;
    END is_paid;
END pkg_payment;
