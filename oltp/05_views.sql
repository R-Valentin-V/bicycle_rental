CREATE OR REPLACE VIEW V_ACTIVE_BOOKINGS AS
SELECT
    bk.booking_id,
    bk.client_id,
    c.full_name AS client_name,
    c.phone AS client_phone,
    bk.bicycle_id,
    b.inventory_number,
    bm.manufacturer,
    bm.model_name,
    rs.station_name,
    bk.planned_start_at,
    bk.planned_end_at,
    bk.hold_until,
    bk.status,
    bk.estimated_amount,
    bk.created_at
FROM bookings bk
JOIN clients c
  ON c.client_id = bk.client_id
JOIN bicycles b
  ON b.bicycle_id = bk.bicycle_id
JOIN bicycle_models bm
  ON bm.model_id = b.model_id
LEFT JOIN rental_stations rs
  ON rs.station_id = b.station_id
WHERE bk.status IN ('NEW', 'CONFIRMED');

/

CREATE OR REPLACE VIEW V_ACTIVE_RENTALS AS
SELECT
    r.rental_id,
    r.booking_id,
    r.client_id,
    c.full_name AS client_name,
    c.phone AS client_phone,
    r.bicycle_id,
    b.inventory_number,
    bm.manufacturer,
    bm.model_name,
    start_rs.station_name AS start_station_name,
    r.actual_start_at,
    r.planned_end_at,
    r.status,
    r.base_amount,
    r.extension_amount,
    r.penalty_amount,
    r.total_amount
FROM rentals r
JOIN clients c
  ON c.client_id = r.client_id
JOIN bicycles b
  ON b.bicycle_id = r.bicycle_id
JOIN bicycle_models bm
  ON bm.model_id = b.model_id
LEFT JOIN rental_stations start_rs
  ON start_rs.station_id = r.start_station_id
WHERE r.status IN ('ACTIVE', 'OVERDUE');

/

CREATE OR REPLACE VIEW V_AVAILABLE_BICYCLES AS
SELECT
    b.bicycle_id,
    b.inventory_number,
    bm.manufacturer,
    bm.model_name,
    bm.bicycle_type,
    rs.station_id,
    rs.station_name,
    NVL(b.custom_hour_rate, bm.default_hour_rate) AS hour_rate
FROM bicycles b
JOIN bicycle_models bm
  ON bm.model_id = b.model_id
LEFT JOIN rental_stations rs
  ON rs.station_id = b.station_id
WHERE b.status = 'AVAILABLE'
  AND NOT EXISTS (
        SELECT 1
        FROM rentals r
        WHERE r.bicycle_id = b.bicycle_id
          AND r.status IN ('ACTIVE', 'OVERDUE')
  )
  AND NOT EXISTS (
        SELECT 1
        FROM repair_orders ro
        WHERE ro.bicycle_id = b.bicycle_id
          AND ro.status IN (
              'OPEN',
              'DIAGNOSIS',
              'IN_PROGRESS',
              'WAITING_PARTS'
          )
  );

/

CREATE OR REPLACE VIEW V_BICYCLE_FULL_INFO AS
SELECT
    b.bicycle_id,
    b.inventory_number,
    bm.manufacturer,
    bm.model_name,
    bm.bicycle_type,
    rs.station_id,
    rs.station_name,
    rs.address AS station_address,
    b.status,
    NVL(b.custom_hour_rate, bm.default_hour_rate) AS hour_rate,
    b.purchase_date,
    b.last_service_date
FROM bicycles b
JOIN bicycle_models bm
  ON bm.model_id = b.model_id
LEFT JOIN rental_stations rs
  ON rs.station_id = b.station_id;

/

CREATE OR REPLACE VIEW V_CLIENT_RENTAL_HISTORY AS
SELECT
    r.rental_id,
    r.client_id,
    c.full_name AS client_name,
    r.bicycle_id,
    b.inventory_number,
    bm.manufacturer,
    bm.model_name,
    start_rs.station_name AS start_station_name,
    end_rs.station_name AS end_station_name,
    r.actual_start_at,
    r.actual_end_at,
    r.status,
    r.base_amount,
    r.extension_amount,
    r.penalty_amount,
    r.total_amount
FROM rentals r
JOIN clients c
  ON c.client_id = r.client_id
JOIN bicycles b
 ON b.bicycle_id = r.bicycle_id
JOIN bicycle_models bm
 ON bm.model_id = b.model_id
LEFT JOIN rental_stations start_rs
  ON start_rs.station_id = r.start_station_id
LEFT JOIN rental_stations end_rs
  ON end_rs.station_id = r.end_station_id;

/

CREATE OR REPLACE VIEW V_OPEN_REPAIRS AS
SELECT
    ro.repair_id,
    ro.bicycle_id,
    b.inventory_number,
    bm.manufacturer,
    bm.model_name,
    ro.status,
    ro.problem_description,
    ro.opened_at,
    ro.started_at,
    opened_staff.full_name AS opened_by_name,

    GREATEST(
        ROUND(
            (
                CAST(SYSTIMESTAMP AS DATE)
                - CAST(ro.opened_at AS DATE)
            ) * 24 * 60
        ),
        0
    ) AS downtime_minutes

FROM repair_orders ro
JOIN bicycles b
  ON b.bicycle_id = ro.bicycle_id
JOIN bicycle_models bm
  ON bm.model_id = b.model_id
LEFT JOIN staff opened_staff
   ON opened_staff.staff_id = ro.opened_by_staff_id
WHERE ro.status IN (
    'OPEN',
    'DIAGNOSIS',
    'IN_PROGRESS',
    'WAITING_PARTS'
);

/

CREATE OR REPLACE VIEW V_OVERDUE_RENTALS AS
SELECT
    r.rental_id,
    r.client_id,
    c.full_name AS client_name,
    c.phone AS client_phone,
    r.bicycle_id,
    b.inventory_number,
    r.actual_start_at,
    r.planned_end_at,
    r.status,

    GREATEST(
        ROUND(
            (
                CAST(SYSTIMESTAMP AS DATE)
                - CAST(r.planned_end_at AS DATE)
            ) * 24 * 60
        ),
        0
    ) AS overdue_minutes,

    r.penalty_amount,
    r.total_amount
FROM rentals r
JOIN clients c
  ON c.client_id = r.client_id
JOIN bicycles b
  ON b.bicycle_id = r.bicycle_id
WHERE r.status = 'OVERDUE'
   OR (
        r.status = 'ACTIVE'
        AND r.planned_end_at < SYSTIMESTAMP
   );

