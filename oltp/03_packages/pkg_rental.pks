CREATE OR REPLACE PACKAGE pkg_rental AS

    c_status_active    CONSTANT VARCHAR2(20) := 'ACTIVE';
    c_status_overdue   CONSTANT VARCHAR2(20) := 'OVERDUE';
    c_status_completed CONSTANT VARCHAR2(20) := 'COMPLETED';
    c_status_cancelled CONSTANT VARCHAR2(20) := 'CANCELLED';

    /**
     * Начинает аренду на основании подтверждённого бронирования.
     *
     * Создаёт RENTALS, переводит BOOKING в COMPLETED
     * и велосипед в RENTED.
     */
    PROCEDURE start_from_booking (
        p_booking_id       IN bookings.booking_id%TYPE,
        p_start_station_id IN rental_stations.station_id%TYPE,
        p_staff_id         IN staff.staff_id%TYPE,
        p_rental_id        OUT rentals.rental_id%TYPE
    );

    /**
     * Начинает аренду без предварительного бронирования.
     */
    PROCEDURE start_without_booking (
        p_client_id        IN clients.client_id%TYPE,
        p_bicycle_id       IN bicycles.bicycle_id%TYPE,
        p_start_station_id IN rental_stations.station_id%TYPE,
        p_planned_end_at   IN TIMESTAMP,
        p_staff_id         IN staff.staff_id%TYPE,
        p_rental_id        OUT rentals.rental_id%TYPE
    );

    /**
     * Рассчитывает стоимость продления.
     */
    FUNCTION calculate_extension_amount (
        p_rental_id        IN rentals.rental_id%TYPE,
        p_new_end_at       IN TIMESTAMP
    ) RETURN NUMBER;

    /**
     * Продлевает активную или просроченную аренду.
     *
     * Проверяет:
     * - новый срок позже текущего;
     * - отсутствие следующего пересекающегося бронирования;
     * - отсутствие активной заявки на ремонт;
     * - допустимый статус аренды.
     *
     * Создаёт строку в RENTAL_EXTENSIONS.
     */
    PROCEDURE extend_rental (
        p_rental_id   IN rentals.rental_id%TYPE,
        p_new_end_at  IN TIMESTAMP,
        p_extension_id OUT rental_extensions.extension_id%TYPE
    );

    /**
     * Рассчитывает штраф на указанную дату.
     */
    FUNCTION calculate_penalty (
        p_rental_id IN rentals.rental_id%TYPE,
        p_as_of     IN TIMESTAMP DEFAULT SYSTIMESTAMP
    ) RETURN NUMBER;

    /**
     * Завершает аренду.
     *
     * Устанавливает фактическое время завершения,
     * станцию возврата, итоговую сумму и статус COMPLETED.
     * Велосипед переводится в AVAILABLE.
     */
    PROCEDURE finish_rental (
        p_rental_id     IN rentals.rental_id%TYPE,
        p_end_station_id IN rental_stations.station_id%TYPE,
        p_staff_id      IN staff.staff_id%TYPE,
        p_actual_end_at IN TIMESTAMP DEFAULT SYSTIMESTAMP
    );

    /**
     * Переводит все просроченные активные аренды
     * в статус OVERDUE.
     *
     * Предназначена для фоновой джобы.
     */
    PROCEDURE mark_overdue_rentals;

    /**
     * Возвращает неоплаченную сумму по аренде.
     *
     * Общая стоимость аренды минус успешные платежи.
     */
    FUNCTION get_outstanding_amount (
        p_rental_id IN rentals.rental_id%TYPE
    ) RETURN NUMBER;

END pkg_rental;
