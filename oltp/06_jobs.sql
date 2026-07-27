BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_EXPIRE_BOOKINGS',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'PKG_BOOKING.EXPIRE_OVERDUE_BOOKINGS',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=15',
        enabled         => FALSE,
        auto_drop       => FALSE,
        comments        => 'автоматическое завершение просроченных бронирований'
    );
END;
/
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'JOB_MARK_OVERDUE_RENTALS',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'PKG_RENTAL.MARK_OVERDUE_RENTALS',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=20',
        enabled         => FALSE,
        auto_drop       => FALSE,
        comments        => 'отметка просроченных аренд'
    );
END;
/
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name            => 'JOB_DAILY_MAINTENANCE_CHECK',
        job_type            => 'STORED_PROCEDURE',
        job_action          => 'PKG_BICYCLE.CHECK_MAINTENANCE_DUE',
        number_of_arguments => 1,
        start_date          => SYSTIMESTAMP,
        repeat_interval     => 'FREQ=DAILY;BYHOUR=2;BYMINUTE=0;BYSECOND=0',
        enabled             => FALSE,
        auto_drop           => FALSE,
        comments            => 'проверка велосипедов, которым требуетс¤ техническое обслуживание'
    );

    DBMS_SCHEDULER.SET_JOB_ARGUMENT_VALUE(
        job_name          => 'JOB_DAILY_MAINTENANCE_CHECK',
        argument_position => 1,
        argument_value    => '90'
    );
END;
/
