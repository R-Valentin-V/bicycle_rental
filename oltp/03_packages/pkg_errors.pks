CREATE OR REPLACE PACKAGE pkg_errors AS

    c_not_found              CONSTANT PLS_INTEGER := -20001;
    c_invalid_status         CONSTANT PLS_INTEGER := -20002;
    c_client_blocked         CONSTANT PLS_INTEGER := -20003;
    c_bicycle_unavailable    CONSTANT PLS_INTEGER := -20004;
    c_booking_overlap        CONSTANT PLS_INTEGER := -20005;
    c_invalid_period         CONSTANT PLS_INTEGER := -20006;
    c_rental_completed       CONSTANT PLS_INTEGER := -20007;
    c_extension_not_allowed  CONSTANT PLS_INTEGER := -20008;
    c_payment_processed      CONSTANT PLS_INTEGER := -20009;
    c_active_repair_exists   CONSTANT PLS_INTEGER := -20010;
    c_payment_insufficient   CONSTANT PLS_INTEGER := -20011;
    c_station_closed         CONSTANT PLS_INTEGER := -20012;
    c_rental_not_created      CONSTANT PLS_INTEGER := -20013;
    c_payment_source_missing  CONSTANT PLS_INTEGER := -20014;
    c_payment_not_created     CONSTANT PLS_INTEGER := -20015;
    c_payment_not_success     CONSTANT PLS_INTEGER := -20016;
    c_payment_not_failed      CONSTANT PLS_INTEGER := -20017;
    c_payment_source_ambiguous CONSTANT PLS_INTEGER := -20018;
    c_problem_description_missing CONSTANT PLS_INTEGER := -20019;

    PROCEDURE raise_error (
        p_error_code IN PLS_INTEGER,
        p_message    IN VARCHAR2
    );

END pkg_errors;
