CREATE OR REPLACE TRIGGER trg_bicycles_updated_at
BEFORE UPDATE ON bicycles
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
END trg_bicycles_updated_at;

/

CREATE OR REPLACE TRIGGER trg_clients_updated_at
BEFORE UPDATE ON clients
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
END trg_clients_updated_at;

/
CREATE OR REPLACE TRIGGER trg_payments_no_delete
BEFORE DELETE ON payments
BEGIN
  RAISE_APPLICATION_ERROR(
      -20020,
      'Записи платежей нельзя удалять'
  );
END;

/
CREATE OR REPLACE TRIGGER trg_payments_protect_success
BEFORE UPDATE OF
         amount,
         currency_code,
         client_id,
         rental_id,
         booking_id,
         payment_type,
         external_payment_id
         ON payments
FOR EACH ROW
BEGIN
  RAISE_APPLICATION_ERROR(
      -20020,
      'Записи успешных платежей нельзя изменять'
  );
END trg_payments_protect_success;

/

CREATE OR REPLACE TRIGGER trg_rentals_no_delete
BEFORE DELETE ON rentals
BEGIN
  RAISE_APPLICATION_ERROR(
      -20020,
      'Записи аренды нельзя удалять'
  );
END;

/

CREATE OR REPLACE TRIGGER trg_rentals_protect_completed
BEFORE UPDATE OF
          client_id,
          bicycle_id,
          booking_id,
          actual_start_at,
          actual_end_at,
          start_station_id,
          end_station_id,
          total_amount
         ON rentals
FOR EACH ROW
BEGIN
    IF :OLD.status = pkg_rental.c_status_completed THEN
        RAISE_APPLICATION_ERROR(
             -20020,
             'Завершённая аренда неизменяема'
        );
    END IF;
END;

/

CREATE OR REPLACE TRIGGER trg_rentals_updated_at
BEFORE UPDATE ON rentals
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
END trg_rentals_updated_at;

/

CREATE OR REPLACE TRIGGER trg_repair_orders_no_delete
BEFORE DELETE ON repair_orders
BEGIN
  RAISE_APPLICATION_ERROR(
      -20020,
      'Записи заявки на ремонт нельзя удалять'
  );
END;

/

CREATE OR REPLACE TRIGGER trg_staff_updated_at
BEFORE UPDATE ON staff
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
END trg_staff_updated_at;

/

CREATE OR REPLACE TRIGGER trg_stations_updated_at
BEFORE UPDATE ON rental_stations
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
END trg_stations_updated_at;
