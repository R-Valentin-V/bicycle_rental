CREATE OR REPLACE PACKAGE pkg_payment AS

    c_status_created  CONSTANT VARCHAR2(20) := 'CREATED';
    c_status_pending  CONSTANT VARCHAR2(20) := 'PENDING';
    c_status_success  CONSTANT VARCHAR2(20) := 'SUCCESS';
    c_status_failed   CONSTANT VARCHAR2(20) := 'FAILED';
    c_status_refunded CONSTANT VARCHAR2(20) := 'REFUNDED';

    c_type_booking   CONSTANT VARCHAR2(20) := 'BOOKING';
    c_type_rental    CONSTANT VARCHAR2(20) := 'RENTAL';
    c_type_extension CONSTANT VARCHAR2(20) := 'EXTENSION';
    c_type_penalty   CONSTANT VARCHAR2(20) := 'PENALTY';
    c_type_refund    CONSTANT VARCHAR2(20) := 'REFUND';

    /**
     * Создаёт новый платёж.
     *
     * Хотя бы один из параметров p_rental_id или p_booking_id
     * должен быть указан.
     *
     * При повторной передаче существующего idempotency_key
     * новый платёж не создается.
     */
    PROCEDURE create_payment (
        p_client_id       IN clients.client_id%TYPE,
        p_rental_id       IN rentals.rental_id%TYPE DEFAULT NULL,
        p_booking_id      IN bookings.booking_id%TYPE DEFAULT NULL,
        p_payment_type    IN payments.payment_type%TYPE,
        p_amount          IN payments.amount%TYPE,
        p_payment_method  IN payments.payment_method%TYPE,
        p_idempotency_key IN payments.idempotency_key%TYPE,
        p_payment_id      OUT payments.payment_id%TYPE
    );

    /**
     * Переводит платёж в статус PENDING.
     */
    PROCEDURE mark_pending (
        p_payment_id IN payments.payment_id%TYPE,
        p_external_payment_id IN payments.external_payment_id%TYPE
    );

    /**
     * Фиксирует успешное выполнение платежа.
     */
    PROCEDURE mark_success (
        p_payment_id IN payments.payment_id%TYPE,
        p_external_payment_id IN payments.external_payment_id%TYPE DEFAULT NULL,
        p_paid_at    IN TIMESTAMP DEFAULT SYSTIMESTAMP
    );

    /**
     * Фиксирует неуспешный результат платежа.
     */
    PROCEDURE mark_failed (
        p_payment_id    IN payments.payment_id%TYPE,
        p_failure_reason IN payments.failure_reason%TYPE,
        p_error_code    IN NUMBER DEFAULT NULL,
        p_failed_at     IN TIMESTAMP DEFAULT SYSTIMESTAMP
    );

    /**
     * Создаёт операцию возврата.
     *
     * p_source_payment_id — исходный успешный платёж.
     */
    PROCEDURE create_refund (
        p_source_payment_id IN payments.payment_id%TYPE,
        p_amount            IN payments.amount%TYPE,
        p_idempotency_key   IN payments.idempotency_key%TYPE,
        p_refund_payment_id OUT payments.payment_id%TYPE
    );

    /**
     * Возвращает сумму успешных платежей по аренде.
     */
    FUNCTION get_success_amount (
        p_rental_id IN rentals.rental_id%TYPE
    ) RETURN NUMBER;

    /**
     * Проверяет, оплачена ли указанная сумма.
     *
     * Возвращает:
     * 1 — оплачена;
     * 0 — не оплачена.
     */
    FUNCTION is_paid (
        p_rental_id       IN rentals.rental_id%TYPE,
        p_required_amount IN NUMBER
    ) RETURN NUMBER;

END pkg_payment;
