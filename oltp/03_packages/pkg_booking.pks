CREATE OR REPLACE PACKAGE pkg_booking AS

    c_status_new       CONSTANT VARCHAR2(20) := 'NEW';
    c_status_confirmed CONSTANT VARCHAR2(20) := 'CONFIRMED';
    c_status_cancelled CONSTANT VARCHAR2(20) := 'CANCELLED';
    c_status_expired   CONSTANT VARCHAR2(20) := 'EXPIRED';
    c_status_completed CONSTANT VARCHAR2(20) := 'COMPLETED';
    
    /**
     * Рассчитывает время аренды.
     */    
    FUNCTION calc_hours (
        p_start_time IN TIMESTAMP,
        p_end_time   IN TIMESTAMP
    ) RETURN NUMBER;
    /**
     * Рассчитывает предварительную стоимость бронирования.
     */
    FUNCTION calculate_amount (
        p_bicycle_id IN bicycles.bicycle_id%TYPE,
        p_start_at   IN TIMESTAMP,
        p_end_at     IN TIMESTAMP
    ) RETURN bookings.estimated_amount%TYPE;

    /**
     * Создаёт новое бронирование.
     *
     * Проверяет:
     * - существование и статус клиента;
     * - корректность периода;
     * - доступность велосипеда;
     * - отсутствие пересекающихся бронирований;
     * - рабочий статус станции.
     *
     * p_hold_minutes определяет срок удержания неоплаченной брони.
     * В p_booking_id возвращается идентификатор созданной записи.
     */
    PROCEDURE create_booking (
        p_client_id     IN clients.client_id%TYPE,
        p_bicycle_id    IN bicycles.bicycle_id%TYPE,
        p_start_at      IN TIMESTAMP,
        p_end_at        IN TIMESTAMP,
        p_hold_minutes  IN PLS_INTEGER DEFAULT 15,
        p_booking_id    OUT bookings.booking_id%TYPE
    );

    /**
     * Подтверждает бронирование.
     *
     * Допустимый исходный статус — NEW.
     */
    PROCEDURE confirm_booking (
        p_booking_id IN bookings.booking_id%TYPE
    );

    /**
     * Отменяет бронирование.
     *
     * Нельзя отменить бронь, уже преобразованную в аренду.
     */
    PROCEDURE cancel_booking (
        p_booking_id IN bookings.booking_id%TYPE
    );

    /**
     * Переводит одну просроченную неоплаченную бронь
     * в статус EXPIRED.
     */
    PROCEDURE expire_booking (
        p_booking_id IN bookings.booking_id%TYPE
    );

    /**
     * Обрабатывает все бронирования со статусом NEW,
     * у которых истёк HOLD_UNTIL.
     *
     * Предназначена для вызова из DBMS_SCHEDULER.
     */
    PROCEDURE expire_overdue_bookings;

    /**
     * Проверяет, разрешено ли начать аренду по бронированию.
     *
     * Возвращает:
     * 1 — можно начать;
     * 0 — нельзя.
     */
    FUNCTION can_be_started (
        p_booking_id IN bookings.booking_id%TYPE
    ) RETURN NUMBER;

END pkg_booking;
