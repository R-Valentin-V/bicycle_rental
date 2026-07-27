CREATE INDEX ix_bicycles_station_status
    ON bicycles (station_id, status);

CREATE INDEX ix_bookings_bicycle_period
    ON bookings (bicycle_id, status, planned_start_at, planned_end_at);

CREATE INDEX ix_bookings_client_created
    ON bookings (client_id, created_at);

CREATE INDEX ix_rentals_bicycle_status
    ON rentals (bicycle_id, status);

CREATE INDEX ix_rentals_client_start
    ON rentals (client_id, actual_start_at);

CREATE INDEX ix_rentals_start_station
    ON rentals (start_station_id);

CREATE INDEX ix_rentals_end_station
    ON rentals (end_station_id);

CREATE INDEX ix_payments_rental_status
    ON payments (rental_id, status);

CREATE INDEX ix_payments_booking_status
    ON payments (booking_id, status);

CREATE INDEX ix_repair_orders_bicycle_status
    ON repair_orders (bicycle_id, status);

CREATE INDEX ix_bicycle_history_bicycle_date
    ON bicycle_status_history (bicycle_id, changed_at);

CREATE INDEX ix_audit_log_entity
    ON audit_log (entity_name, entity_id, event_time);

CREATE INDEX ix_audit_log_event_time
    ON audit_log (event_time);
