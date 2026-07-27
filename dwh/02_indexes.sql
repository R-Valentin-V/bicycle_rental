CREATE INDEX ix_dim_client_natural_key
    ON dim_client (
        client_id,
        is_current
    );	
CREATE INDEX ix_dim_client_history
    ON dim_client (
        client_id,
        valid_from,
        valid_to
    );
CREATE INDEX ix_dim_station_natural_key
    ON dim_station (
        station_id,
        is_current
    );

CREATE INDEX ix_dim_station_history
    ON dim_station (
        station_id,
        valid_from,
        valid_to
    );
CREATE INDEX ix_dim_bicycle_natural_key
    ON dim_bicycle (
        bicycle_id,
        is_current
    );

CREATE INDEX ix_dim_bicycle_history
    ON dim_bicycle (
        bicycle_id,
        valid_from,
        valid_to
    );

CREATE INDEX ix_dim_bicycle_model
    ON dim_bicycle (
        manufacturer,
        model_name,
        bicycle_type
    );
CREATE INDEX ix_fact_rentals_client
    ON fact_rentals (
        client_key,
        start_date_key
    );

CREATE INDEX ix_fact_rentals_bicycle
    ON fact_rentals (
        bicycle_key,
        start_date_key
    );

CREATE INDEX ix_fact_rentals_start_station
    ON fact_rentals (
        start_station_key,
        start_date_key
    );

CREATE INDEX ix_fact_rentals_status
    ON fact_rentals (
        rental_status,
        start_date_key
    );
CREATE INDEX ix_fact_payments_client
    ON fact_payments (
        client_key,
        payment_date_key
    );

CREATE INDEX ix_fact_payments_bicycle
    ON fact_payments (
        bicycle_key,
        payment_date_key
    );

CREATE INDEX ix_fact_payments_rental
    ON fact_payments (rental_id);

CREATE INDEX ix_fact_payments_type
    ON fact_payments (
        payment_type,
        payment_date_key
    );

CREATE INDEX ix_fact_payments_status
    ON fact_payments (
        payment_status,
        payment_date_key
    );
CREATE INDEX ix_fact_repairs_bicycle
    ON fact_repairs (
        bicycle_key,
        opened_date_key
    );

CREATE INDEX ix_fact_repairs_status
    ON fact_repairs (
        repair_status,
        opened_date_key
    );

CREATE INDEX ix_fact_repairs_completed
    ON fact_repairs (
        is_completed,
        opened_date_key
    );
CREATE INDEX ix_etl_log_process
    ON etl_log (
        process_name,
        start_dttm
    );

CREATE INDEX ix_etl_log_status
    ON etl_log (
        status,
        start_dttm
    );
