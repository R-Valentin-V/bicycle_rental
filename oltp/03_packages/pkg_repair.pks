CREATE OR REPLACE PACKAGE pkg_repair AS

    c_status_open        CONSTANT VARCHAR2(20) := 'OPEN';
    c_status_in_progress CONSTANT VARCHAR2(20) := 'IN_PROGRESS';
    c_status_completed   CONSTANT VARCHAR2(20) := 'COMPLETED';
    c_status_cancelled   CONSTANT VARCHAR2(20) := 'CANCELLED';

    /**
     * Проверяет наличие активной заявки на ремонт.
     *
     * Возвращает:
     * 1 — активный ремонт существует;
     * 0 — активного ремонта нет.
     */
    FUNCTION has_active_repair (
        p_bicycle_id IN bicycles.bicycle_id%TYPE
    ) RETURN NUMBER;

    /**
     * Создаёт заявку на ремонт.
     *
     * Проверяет:
     * - велосипед не находится в активной аренде;
     * - для него нет другой активной заявки;
     * - велосипед не списан.
     *
     * После создания переводит велосипед в REPAIR.
     */
    PROCEDURE open_repair (
        p_bicycle_id          IN bicycles.bicycle_id%TYPE,
        p_opened_by_staff_id  IN staff.staff_id%TYPE,
        p_problem_description IN repair_orders.problem_description%TYPE,
        p_repair_id           OUT repair_orders.repair_id%TYPE
    );

    /**
     * Начинает выполнение ремонта.
     *
     * Допустимый исходный статус заявки — OPEN.
     */
    PROCEDURE start_repair (
        p_repair_id  IN repair_orders.repair_id%TYPE,
        p_staff_id   IN staff.staff_id%TYPE
    );

    /**
     * Завершает ремонт.
     *
     * p_return_status:
     * AVAILABLE — велосипед готов к эксплуатации;
     * BLOCKED — требуется дополнительная проверка.
     */
    PROCEDURE complete_repair (
        p_repair_id      IN repair_orders.repair_id%TYPE,
        p_closed_by_staff_id IN staff.staff_id%TYPE,
        p_repair_result  IN repair_orders.repair_result%TYPE,
        p_repair_cost    IN repair_orders.repair_cost%TYPE,
        p_return_status  IN bicycles.status%TYPE DEFAULT 'AVAILABLE'
    );

    /**
     * Отменяет заявку на ремонт.
     *
     * Разрешено только для OPEN или IN_PROGRESS.
     */
    PROCEDURE cancel_repair (
        p_repair_id  IN repair_orders.repair_id%TYPE,
        p_staff_id   IN staff.staff_id%TYPE,
        p_reason     IN VARCHAR2
    );

END pkg_repair;
