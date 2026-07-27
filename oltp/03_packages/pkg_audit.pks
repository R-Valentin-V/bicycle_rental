CREATE OR REPLACE PACKAGE pkg_audit AS

    /**
     * Записывает бизнес-событие в журнал аудита.
     *
     * audit_type    — EVENT, ERROR.
     * p_action_code — код действия.
     * p_entity_name — имя сущности или таблицы.
     * p_entity_id   — идентификатор изменённой записи.
     * p_old_data    — состояние до изменения.
     * p_new_data    — состояние после изменения.
     */
    PROCEDURE write_event (
        p_audit_type  IN audit_log.audit_type%TYPE,
        p_action_code IN audit_log.action_code%TYPE,
        p_entity_name IN audit_log.entity_name%TYPE,
        p_entity_id   IN audit_log.entity_id%TYPE,
        p_old_data    IN audit_log.old_data%TYPE,
        p_new_data    IN audit_log.new_data%TYPE
    );

    /**
     * Записывает ошибку выполнения операции.
     *
     * Использует автономную транзакцию, поэтому запись об ошибке
     * сохраняется даже при откате основной бизнес-транзакции.
     */
    PROCEDURE write_error (
        p_audit_type  IN audit_log.audit_type%TYPE,
        p_action_code   IN audit_log.action_code%TYPE,
        p_entity_name   IN audit_log.entity_name%TYPE,
        p_entity_id     IN audit_log.entity_id%TYPE,
        p_error_code    IN audit_log.error_code%TYPE,
        p_error_message IN audit_log.error_message%TYPE
    );

END pkg_audit;
