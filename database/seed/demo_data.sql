-- Клиенты
INSERT INTO clients (
    client_id, full_name, phone, email, registration_date, status
) VALUES (
    1, 'Иван Петров', '+7-900-111-22-33', 'ivan.petrov@example.ru',
    DATE '2026-01-10', 'ACTIVE'
);

INSERT INTO clients (
    client_id, full_name, phone, email, registration_date, status
) VALUES (
    2, 'Анна Смирнова', '+7-900-222-33-44', 'anna.smirnova@example.ru',
    DATE '2026-02-05', 'ACTIVE'
);

INSERT INTO clients (
    client_id, full_name, phone, email, registration_date, status
) VALUES (
    3, 'Михаил Соколов', '+7-900-333-44-55', 'mikhail.sokolov@example.ru',
    DATE '2026-03-12', 'BLOCKED'
);

INSERT INTO clients (
    client_id, full_name, phone, email, registration_date, status
) VALUES (
    4, 'Елена Кузнецова', '+7-900-444-55-66', 'elena.kuznetsova@example.ru',
    DATE '2026-04-20', 'ACTIVE'
);

INSERT INTO clients (
    client_id, full_name, phone, email, registration_date, status
) VALUES (
    5, 'Дмитрий Волков', '+7-900-555-66-77', 'dmitry.volkov@example.ru',
    DATE '2026-05-15', 'ACTIVE'
);


-- Сотрудники
INSERT INTO staff (
    staff_id, full_name, job_title, login_name, status
) VALUES (
    1, 'Сергей Орлов', 'Администратор проката', 's.orlov', 'ACTIVE'
);

INSERT INTO staff (
    staff_id, full_name, job_title, login_name, status
) VALUES (
    2, 'Ольга Морозова', 'Механик', 'o.morozova', 'ACTIVE'
);

INSERT INTO staff (
    staff_id, full_name, job_title, login_name, status
) VALUES (
    3, 'Алексей Фёдоров', 'Старший администратор', 'a.fedorov', 'ACTIVE'
);


-- Станции
INSERT INTO rental_stations (
    station_id, station_name, address, phone, status
) VALUES (
    1, 'Центральный парк', 'г. Москва, ул. Парковая, д. 10',
    '+7-495-100-10-10', 'ACTIVE'
);

INSERT INTO rental_stations (
    station_id, station_name, address, phone, status
) VALUES (
    2, 'Набережная', 'г. Москва, Фрунзенская набережная, д. 24',
    '+7-495-200-20-20', 'ACTIVE'
);

INSERT INTO rental_stations (
    station_id, station_name, address, phone, status
) VALUES (
    3, 'Университет', 'г. Москва, Университетский проспект, д. 5',
    '+7-495-300-30-30', 'TEMPORARILY_CLOSED'
);


-- Модели велосипедов
INSERT INTO bicycle_models (
    model_id, manufacturer, model_name, bicycle_type,
    default_hour_rate, description
) VALUES (
    1, 'Forward', 'Valencia 2.0', 'CITY',
    250, 'Городской велосипед для спокойных поездок'
);

INSERT INTO bicycle_models (
    model_id, manufacturer, model_name, bicycle_type,
    default_hour_rate, description
) VALUES (
    2, 'Stels', 'Navigator 500', 'MOUNTAIN',
    350, 'Горный велосипед начального уровня'
);

INSERT INTO bicycle_models (
    model_id, manufacturer, model_name, bicycle_type,
    default_hour_rate, description
) VALUES (
    3, 'Format', '5222', 'ROAD',
    450, 'Шоссейный велосипед для длительных поездок'
);

INSERT INTO bicycle_models (
    model_id, manufacturer, model_name, bicycle_type,
    default_hour_rate, description
) VALUES (
    4, 'Eltreco', 'Wave 350W', 'ELECTRIC',
    700, 'Электровелосипед с запасом хода до 45 км'
);


-- Велосипеды
INSERT INTO bicycles (
    bicycle_id, inventory_number, model_id, station_id, status,
    custom_hour_rate, purchase_date, last_service_date
) VALUES (
    1, 'BIKE-001', 1, 1, 'AVAILABLE',
    NULL, DATE '2025-04-10', DATE '2026-06-15'
);

INSERT INTO bicycles (
    bicycle_id, inventory_number, model_id, station_id, status,
    custom_hour_rate, purchase_date, last_service_date
) VALUES (
    2, 'BIKE-002', 1, 1, 'RESERVED',
    NULL, DATE '2025-04-10', DATE '2026-06-15'
);

INSERT INTO bicycles (
    bicycle_id, inventory_number, model_id, station_id, status,
    custom_hour_rate, purchase_date, last_service_date
) VALUES (
    3, 'BIKE-003', 2, 2, 'RENTED',
    400, DATE '2025-05-18', DATE '2026-06-20'
);

INSERT INTO bicycles (
    bicycle_id, inventory_number, model_id, station_id, status,
    custom_hour_rate, purchase_date, last_service_date
) VALUES (
    4, 'BIKE-004', 2, 2, 'REPAIR',
    NULL, DATE '2025-05-18', DATE '2026-05-30'
);

INSERT INTO bicycles (
    bicycle_id, inventory_number, model_id, station_id, status,
    custom_hour_rate, purchase_date, last_service_date
) VALUES (
    5, 'BIKE-005', 3, 1, 'AVAILABLE',
    NULL, DATE '2025-07-01', DATE '2026-06-25'
);

INSERT INTO bicycles (
    bicycle_id, inventory_number, model_id, station_id, status,
    custom_hour_rate, purchase_date, last_service_date
) VALUES (
    6, 'BIKE-006', 4, 2, 'AVAILABLE',
    750, DATE '2026-01-15', DATE '2026-07-01'
);

INSERT INTO bicycles (
    bicycle_id, inventory_number, model_id, station_id, status,
    custom_hour_rate, purchase_date, last_service_date
) VALUES (
    7, 'BIKE-007', 4, 1, 'BLOCKED',
    NULL, DATE '2026-01-15', DATE '2026-06-10'
);


-- Бронирования
INSERT INTO bookings (
    booking_id, client_id, bicycle_id,
    planned_start_at, planned_end_at, hold_until,
    status, estimated_amount, created_at, confirmed_at
) VALUES (
    1, 1, 2,
    TIMESTAMP '2026-07-12 10:00:00',
    TIMESTAMP '2026-07-12 13:00:00',
    TIMESTAMP '2026-07-11 20:15:00',
    'CONFIRMED', 750,
    TIMESTAMP '2026-07-11 20:00:00',
    TIMESTAMP '2026-07-11 20:05:00'
);

INSERT INTO bookings (
    booking_id, client_id, bicycle_id,
    planned_start_at, planned_end_at, hold_until,
    status, estimated_amount, created_at
) VALUES (
    2, 2, 5,
    TIMESTAMP '2026-07-13 09:00:00',
    TIMESTAMP '2026-07-13 11:00:00',
    TIMESTAMP '2026-07-11 21:15:00',
    'NEW', 900,
    TIMESTAMP '2026-07-11 21:00:00'
);

INSERT INTO bookings (
    booking_id, client_id, bicycle_id,
    planned_start_at, planned_end_at, hold_until,
    status, estimated_amount, created_at, cancelled_at,
    cancellation_reason
) VALUES (
    3, 4, 1,
    TIMESTAMP '2026-07-10 15:00:00',
    TIMESTAMP '2026-07-10 17:00:00',
    TIMESTAMP '2026-07-09 18:15:00',
    'CANCELLED', 500,
    TIMESTAMP '2026-07-09 18:00:00',
    TIMESTAMP '2026-07-09 19:00:00',
    'Клиент изменил планы'
);

INSERT INTO bookings (
    booking_id, client_id, bicycle_id,
    planned_start_at, planned_end_at, hold_until,
    status, estimated_amount, created_at, confirmed_at
) VALUES (
    4, 5, 3,
    TIMESTAMP '2026-07-11 16:00:00',
    TIMESTAMP '2026-07-11 18:00:00',
    TIMESTAMP '2026-07-11 15:15:00',
    'COMPLETED', 800,
    TIMESTAMP '2026-07-11 15:00:00',
    TIMESTAMP '2026-07-11 15:05:00'
);


-- Аренды
INSERT INTO rentals (
    rental_id, booking_id, client_id, bicycle_id,
    start_station_id, end_station_id,
    planned_end_at, actual_start_at, actual_end_at,
    status, base_amount, extension_amount, penalty_amount, total_amount,
    created_at, updated_at
) VALUES (
    1, 4, 5, 3,
    2, NULL,
    TIMESTAMP '2026-07-11 19:00:00',
    TIMESTAMP '2026-07-11 16:05:00',
    NULL,
    'ACTIVE', 800, 400, 0, 1200,
    TIMESTAMP '2026-07-11 16:05:00',
    TIMESTAMP '2026-07-11 17:30:00'
);

INSERT INTO rentals (
    rental_id, booking_id, client_id, bicycle_id,
    start_station_id, end_station_id,
    planned_end_at, actual_start_at, actual_end_at,
    status, base_amount, extension_amount, penalty_amount, total_amount,
    created_at, updated_at
) VALUES (
    2, NULL, 2, 1,
    1, 2,
    TIMESTAMP '2026-07-08 14:00:00',
    TIMESTAMP '2026-07-08 12:00:00',
    TIMESTAMP '2026-07-08 13:45:00',
    'COMPLETED', 500, 0, 0, 500,
    TIMESTAMP '2026-07-08 12:00:00',
    TIMESTAMP '2026-07-08 13:45:00'
);

INSERT INTO rentals (
    rental_id, booking_id, client_id, bicycle_id,
    start_station_id, end_station_id,
    planned_end_at, actual_start_at, actual_end_at,
    status, base_amount, extension_amount, penalty_amount, total_amount,
    created_at, updated_at
) VALUES (
    3, NULL, 1, 6,
    2, 1,
    TIMESTAMP '2026-07-06 20:00:00',
    TIMESTAMP '2026-07-06 18:00:00',
    TIMESTAMP '2026-07-06 20:30:00',
    'COMPLETED', 1500, 0, 250, 1750,
    TIMESTAMP '2026-07-06 18:00:00',
    TIMESTAMP '2026-07-06 20:30:00'
);


-- Продления
INSERT INTO rental_extensions (
    extension_id, rental_id, old_end_at, new_end_at,
    amount, status, created_at
) VALUES (
    1, 1,
    TIMESTAMP '2026-07-11 18:00:00',
    TIMESTAMP '2026-07-11 19:00:00',
    400, 'PAID',
    TIMESTAMP '2026-07-11 17:25:00'
);


-- Платежи
INSERT INTO payments (
    payment_id, rental_id, booking_id, client_id,
    payment_type, status, amount, currency_code,
    payment_method, external_payment_id, idempotency_key,
    created_at, paid_at
) VALUES (
    1, NULL, 1, 1,
    'BOOKING', 'SUCCESS', 750, 'RUB',
    'BANK_CARD', 'PAY-BOOK-0001', 'IDEMP-BOOK-0001',
    TIMESTAMP '2026-07-11 20:03:00',
    TIMESTAMP '2026-07-11 20:04:00'
);

INSERT INTO payments (
    payment_id, rental_id, booking_id, client_id,
    payment_type, status, amount, currency_code,
    payment_method, external_payment_id, idempotency_key,
    created_at, paid_at
) VALUES (
    2, 1, 4, 5,
    'RENTAL', 'SUCCESS', 800, 'RUB',
    'BANK_CARD', 'PAY-RENT-0001', 'IDEMP-RENT-0001',
    TIMESTAMP '2026-07-11 16:00:00',
    TIMESTAMP '2026-07-11 16:02:00'
);

INSERT INTO payments (
    payment_id, rental_id, booking_id, client_id,
    payment_type, status, amount, currency_code,
    payment_method, external_payment_id, idempotency_key,
    created_at, paid_at
) VALUES (
    3, 1, 4, 5,
    'EXTENSION', 'SUCCESS', 400, 'RUB',
    'СБП', 'PAY-EXT-0001', 'IDEMP-EXT-0001',
    TIMESTAMP '2026-07-11 17:24:00',
    TIMESTAMP '2026-07-11 17:25:00'
);

INSERT INTO payments (
    payment_id, rental_id, booking_id, client_id,
    payment_type, status, amount, currency_code,
    payment_method, external_payment_id, idempotency_key,
    created_at, paid_at
) VALUES (
    4, 2, NULL, 2,
    'RENTAL', 'SUCCESS', 500, 'RUB',
    'CASH', 'PAY-RENT-0002', 'IDEMP-RENT-0002',
    TIMESTAMP '2026-07-08 13:40:00',
    TIMESTAMP '2026-07-08 13:45:00'
);

INSERT INTO payments (
    payment_id, rental_id, booking_id, client_id,
    payment_type, status, amount, currency_code,
    payment_method, external_payment_id, idempotency_key,
    created_at, failed_at, failure_reason
) VALUES (
    5, NULL, 2, 2,
    'BOOKING', 'FAILED', 900, 'RUB',
    'BANK_CARD', 'PAY-BOOK-0002', 'IDEMP-BOOK-0002',
    TIMESTAMP '2026-07-11 21:05:00',
    TIMESTAMP '2026-07-11 21:06:00',
    'Недостаточно средств на карте'
);

INSERT INTO payments (
    payment_id, rental_id, booking_id, client_id,
    payment_type, status, amount, currency_code,
    payment_method, external_payment_id, idempotency_key,
    created_at, paid_at
) VALUES (
    6, 3, NULL, 1,
    'PENALTY', 'SUCCESS', 250, 'RUB',
    'BANK_CARD', 'PAY-PEN-0001', 'IDEMP-PEN-0001',
    TIMESTAMP '2026-07-06 20:31:00',
    TIMESTAMP '2026-07-06 20:32:00'
);


-- Ремонт
INSERT INTO repair_orders (
    repair_id, bicycle_id, opened_by_staff_id, closed_by_staff_id,
    status, problem_description, repair_result, repair_cost,
    opened_at, started_at, completed_at
) VALUES (
    1, 4, 1, NULL,
    'IN_PROGRESS',
    'Не переключаются задние передачи, слышен посторонний шум',
    NULL,
    0,
    TIMESTAMP '2026-07-10 09:00:00',
    TIMESTAMP '2026-07-10 10:30:00',
    NULL
);

INSERT INTO repair_orders (
    repair_id, bicycle_id, opened_by_staff_id, closed_by_staff_id,
    status, problem_description, repair_result, repair_cost,
    opened_at, started_at, completed_at
) VALUES (
    2, 7, 3, 2,
    'COMPLETED',
    'Периодически отключается электропривод',
    'Заменён контроллер электропривода, выполнена диагностика',
    4200,
    TIMESTAMP '2026-06-25 11:00:00',
    TIMESTAMP '2026-06-25 12:00:00',
    TIMESTAMP '2026-06-27 16:00:00'
);


-- История статусов велосипедов
INSERT INTO bicycle_status_history (
    history_id, bicycle_id, old_status, new_status,
    change_reason, changed_by_staff_id, changed_at,
    source_type, source_id
) VALUES (
    1, 2, 'AVAILABLE', 'RESERVED',
    'Велосипед забронирован клиентом', NULL,
    TIMESTAMP '2026-07-11 20:05:00',
    'BOOKING', 1
);

INSERT INTO bicycle_status_history (
    history_id, bicycle_id, old_status, new_status,
    change_reason, changed_by_staff_id, changed_at,
    source_type, source_id
) VALUES (
    2, 3, 'RESERVED', 'RENTED',
    'Клиент получил велосипед', 1,
    TIMESTAMP '2026-07-11 16:05:00',
    'RENTAL', 1
);

INSERT INTO bicycle_status_history (
    history_id, bicycle_id, old_status, new_status,
    change_reason, changed_by_staff_id, changed_at,
    source_type, source_id
) VALUES (
    3, 4, 'AVAILABLE', 'REPAIR',
    'Открыта заявка на ремонт', 1,
    TIMESTAMP '2026-07-10 09:00:00',
    'REPAIR', 1
);

INSERT INTO bicycle_status_history (
    history_id, bicycle_id, old_status, new_status,
    change_reason, changed_by_staff_id, changed_at,
    source_type, source_id
) VALUES (
    4, 7, 'REPAIR', 'BLOCKED',
    'После ремонта требуется контрольная диагностика', 2,
    TIMESTAMP '2026-06-27 16:00:00',
    'REPAIR', 2
);


-- Общий аудит
INSERT INTO audit_log (
    audit_id,
    audit_type,
    event_time,
    action_code,
    entity_name,
    entity_id,
    old_data,
    new_data,
    error_code,
    error_message
) VALUES (
    1,
    'EVENT',
    TIMESTAMP '2026-07-11 20:00:00',
    'BOOKING_CREATED',
    'BOOKINGS',
    1,
    NULL,
    '{"status":"NEW","bicycle_id":2,"estimated_amount":750}',
    NULL,
    NULL
);

INSERT INTO audit_log (
    audit_id,
    audit_type,
    event_time,
    action_code,
    entity_name,
    entity_id,
    old_data,
    new_data,
    error_code,
    error_message
) VALUES (
    2,
    'EVENT',
    TIMESTAMP '2026-07-11 20:05:00',
    'BOOKING_CONFIRMED',
    'BOOKINGS',
    1,
    '{"status":"NEW"}',
    '{"status":"CONFIRMED"}',
    NULL,
    NULL
);

INSERT INTO audit_log (
    audit_id,
    audit_type,
    event_time,
    action_code,
    entity_name,
    entity_id,
    old_data,
    new_data,
    error_code,
    error_message
) VALUES (
    3,
    'EVENT',
    TIMESTAMP '2026-07-11 16:05:00',
    'RENTAL_STARTED',
    'RENTALS',
    1,
    NULL,
    '{"status":"ACTIVE","bicycle_id":3,"client_id":5}',
    NULL,
    NULL
);

INSERT INTO audit_log (
    audit_id,
    audit_type,
    event_time,
    action_code,
    entity_name,
    entity_id,
    old_data,
    new_data,
    error_code,
    error_message
) VALUES (
    4,
    'EVENT',
    TIMESTAMP '2026-07-11 17:25:00',
    'RENTAL_EXTENDED',
    'RENTALS',
    1,
    '{"planned_end_at":"2026-07-11T18:00:00"}',
    '{"planned_end_at":"2026-07-11T19:00:00","extension_amount":400}',
    NULL,
    NULL
);

INSERT INTO audit_log (
    audit_id,
    audit_type,
    event_time,
    action_code,
    entity_name,
    entity_id,
    old_data,
    new_data,
    error_code,
    error_message
) VALUES (
    5,
    'EVENT',
    TIMESTAMP '2026-07-10 09:00:00',
    'REPAIR_OPENED',
    'REPAIR_ORDERS',
    1,
    NULL,
    '{"bicycle_id":4,"status":"IN_PROGRESS"}',
    NULL,
    NULL
);

INSERT INTO audit_log (
    audit_id,
    audit_type,
    event_time,
    action_code,
    entity_name,
    entity_id,
    old_data,
    new_data,
    error_code,
    error_message
) VALUES (
    6,
    'ERROR',
    TIMESTAMP '2026-07-11 21:06:00',
    'PAYMENT_FAILED',
    'PAYMENTS',
    5,
    '{"status":"PENDING"}',
    '{"status":"FAILED"}',
    1001,
    'Недостаточно средств на карте'
);

COMMIT;

