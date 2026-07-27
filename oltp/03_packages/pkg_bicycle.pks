CREATE OR REPLACE PACKAGE pkg_bicycle AS

    -- Статусы велосипеда

    c_status_available CONSTANT bicycles.status%TYPE := 'AVAILABLE';
    c_status_reserved  CONSTANT bicycles.status%TYPE := 'RESERVED';
    c_status_rented    CONSTANT bicycles.status%TYPE := 'RENTED';
    c_status_repair    CONSTANT bicycles.status%TYPE := 'REPAIR';
    c_status_blocked   CONSTANT bicycles.status%TYPE := 'BLOCKED';
    c_status_retired   CONSTANT bicycles.status%TYPE := 'RETIRED';


    /**
     * Возвращает текущий статус велосипеда.
     */
    FUNCTION get_status (
        p_bicycle_id IN bicycles.bicycle_id%TYPE
    ) RETURN bicycles.status%TYPE;


    /**
     * Возвращает почасовой тариф велосипеда.
     *
     * Если custom_hour_rate заполнен, используется он.
     * Иначе возвращается default_hour_rate модели.
     */
    FUNCTION get_hour_rate (
        p_bicycle_id IN bicycles.bicycle_id%TYPE
    ) RETURN bicycles.custom_hour_rate%TYPE;


    /**
     * Проверяет доступность велосипеда на заданный период.
     *
     * Возвращает:
     * 1 — доступен;
     * 0 — недоступен.
     *
     * Проверяет:
     * - статус велосипеда;
     * - пересекающиеся бронирования;
     * - активные аренды;
     * - активные заявки на ремонт.
     */
    FUNCTION is_available (
        p_bicycle_id          IN bicycles.bicycle_id%TYPE,
        p_start_at            IN TIMESTAMP,
        p_end_at              IN TIMESTAMP,
        p_exclude_booking_id  IN bookings.booking_id%TYPE DEFAULT NULL,
        p_exclude_rental_id   IN rentals.rental_id%TYPE DEFAULT NULL
    ) RETURN NUMBER;


    /**
     * Изменяет статус велосипеда.
     *
     * Одновременно создаёт записи:
     * - BICYCLE_STATUS_HISTORY;
     * - AUDIT_LOG.
     */
    PROCEDURE change_status (
        p_bicycle_id  IN bicycles.bicycle_id%TYPE,
        p_new_status  IN bicycles.status%TYPE,
        p_reason      IN bicycle_status_history.change_reason%TYPE,
        p_staff_id    IN staff.staff_id%TYPE DEFAULT NULL,
        p_source_type IN bicycle_status_history.source_type%TYPE DEFAULT NULL,
        p_source_id   IN bicycle_status_history.source_id%TYPE DEFAULT NULL
    );


    /**
     * Перемещает велосипед на другую станцию.
     *
     * Создаёт запись в AUDIT_LOG.
     */
    PROCEDURE move_to_station (
        p_bicycle_id IN bicycles.bicycle_id%TYPE,
        p_station_id IN rental_stations.station_id%TYPE,
        p_staff_id   IN staff.staff_id%TYPE DEFAULT NULL,
        p_reason     IN VARCHAR2 DEFAULT NULL
    );


    /**
     * Проверяет велосипеды, которым давно
     * не проводилось техническое обслуживание.
     */
    PROCEDURE check_maintenance_due (
        p_service_interval_days IN PLS_INTEGER DEFAULT 90
    );

END pkg_bicycle;
