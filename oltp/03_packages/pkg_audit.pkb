CREATE OR REPLACE PACKAGE BODY pkg_audit AS

    PROCEDURE write_event (
        p_audit_type  IN audit_log.audit_type%TYPE,
        p_action_code IN audit_log.action_code%TYPE,
        p_entity_name IN audit_log.entity_name%TYPE,
        p_entity_id   IN audit_log.entity_id%TYPE,
        p_old_data    IN audit_log.old_data%TYPE,
        p_new_data    IN audit_log.new_data%TYPE
    )
    IS
    BEGIN
        INSERT INTO audit_log (
            audit_type,
            event_time,
            action_code,
            entity_name,
            entity_id,
            old_data,
            new_data

        )
        VALUES (
            p_audit_type,
            SYSTIMESTAMP,
            UPPER(p_action_code),
            UPPER(p_entity_name),
            p_entity_id,
            p_old_data,
            p_new_data
            
        );
    END write_event;


    PROCEDURE write_error (
        p_audit_type  IN audit_log.audit_type%TYPE,
        p_action_code   IN audit_log.action_code%TYPE,
        p_entity_name   IN audit_log.entity_name%TYPE,
        p_entity_id     IN audit_log.entity_id%TYPE,
        p_error_code    IN audit_log.error_code%TYPE,
        p_error_message IN audit_log.error_message%TYPE
    )
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_log (
            audit_type,
            event_time,
            action_code,
            entity_name,
            entity_id,
            error_code,
            error_message
        )
        VALUES (
            p_audit_type,
            SYSTIMESTAMP,
            UPPER(p_action_code),
            UPPER(p_entity_name),
            p_entity_id,
            p_error_code,
            SUBSTR(p_error_message, 1, 4000)
        );

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;

            NULL;
    END write_error;

END pkg_audit;
