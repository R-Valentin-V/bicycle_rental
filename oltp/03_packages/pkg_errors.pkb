CREATE OR REPLACE PACKAGE BODY pkg_errors AS

    PROCEDURE raise_error (
        p_error_code IN PLS_INTEGER,
        p_message    IN VARCHAR2
    )
    IS
    BEGIN
        IF p_error_code NOT BETWEEN -20999 AND -20000 THEN
            RAISE_APPLICATION_ERROR(
                -20999,
                'Недопустимый пользовательский код ошибки: '
                || p_error_code
            );
        END IF;

        RAISE_APPLICATION_ERROR(
            p_error_code,
            p_message
        );
    END raise_error;

END pkg_errors;
