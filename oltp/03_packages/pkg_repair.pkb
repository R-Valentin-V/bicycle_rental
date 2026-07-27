CREATE OR REPLACE PACKAGE BODY pkg_repair AS

    FUNCTION has_active_repair (
        p_bicycle_id IN bicycles.bicycle_id%TYPE
    ) RETURN NUMBER
    IS
      l_dummy NUMBER;
    BEGIN

        SELECT 1
        INTO l_dummy
        FROm repair_orders
        WHERE bicycle_id = p_bicycle_id AND
              ROWNUM = 1;

       RETURN 1;

       EXCEPTION
         WHEN NO_DATA_FOUND THEN
           RETURN 0;

    END has_active_repair;

    PROCEDURE open_repair (
        p_bicycle_id          IN  bicycles.bicycle_id%TYPE,
        p_opened_by_staff_id  IN  staff.staff_id%TYPE,
        p_problem_description IN  repair_orders.problem_description%TYPE,
        p_repair_id           OUT repair_orders.repair_id%TYPE
    ) IS
        l_status_bicycle  bicycles.status%TYPE;
    BEGIN
        IF TRIM(p_problem_description) IS NULL THEN
            pkg_errors.raise_error(
                pkg_errors.c_problem_description_missing,
                'Описание проблемы обязательно'
            );
        END IF;
        l_status_bicycle := pkg_bicycle.get_status(p_bicycle_id);

        IF has_active_repair(p_bicycle_id) = 1 THEN
            pkg_errors.raise_error(
                pkg_errors.c_active_repair_exists,
                'Активный ремонт уже существует для bicycle_id=' || p_bicycle_id
            );
        END IF;

        IF l_status_bicycle NOT IN(pkg_bicycle.c_status_blocked, pkg_bicycle.c_status_available) THEN
            pkg_errors.raise_error(
                pkg_errors.c_bicycle_unavailable,
                'Велосипед недоступен. bicycle_id=' || p_bicycle_id ||
                ', текущий статус=' || l_status_bicycle
            );
        END IF;


        INSERT INTO repair_orders (
            bicycle_id,
            opened_by_staff_id,
            status,
            problem_description,
            opened_at
        )
        VALUES (
            p_bicycle_id,
            p_opened_by_staff_id,
            c_status_open,
            p_problem_description,
            SYSTIMESTAMP
        )
        RETURNING repair_id INTO p_repair_id;

        pkg_bicycle.change_status(
            p_bicycle_id  => p_bicycle_id,
            p_new_status  => pkg_bicycle.c_status_repair,
            p_reason      => 'Открытие заявки на ремонт',
            p_staff_id    => p_opened_by_staff_id,
            p_source_type => 'REPAIR',
            p_source_id   => p_repair_id
        );

        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'OPEN_REPAIR',
            p_entity_name => 'REPAIR_ORDERS',
            p_entity_id   => p_repair_id,
            p_old_data    => 'status ' || l_status_bicycle,
            p_new_data    =>  'repair_id ' || p_repair_id
        );
    END open_repair;

    PROCEDURE start_repair (
        p_repair_id  IN repair_orders.repair_id%TYPE,
        p_staff_id   IN staff.staff_id%TYPE
    ) IS
        l_status_repair repair_orders.status%TYPE;
        l_bicycle_id    bicycles.bicycle_id%TYPE;

    BEGIN
        SELECT bicycle_id,
               status
        INTO l_bicycle_id,
             l_status_repair
        FROM repair_orders
        WHERE repair_id = p_repair_id
        FOR UPDATE;

        IF l_status_repair != c_status_open THEN
          pkg_errors.raise_error(
              pkg_errors.c_invalid_status,
              'Недопустимый статус' || l_status_repair
          );
        END IF;

        UPDATE repair_orders
        SET status     = c_status_in_progress,
            started_at = SYSTIMESTAMP
        WHERE repair_id = p_repair_id;

        
        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'START_REPAIR',
            p_entity_name => 'REPAIR_ORDERS',
            p_entity_id   => p_repair_id,
            p_old_data    => NULL,
            p_new_data    =>  'repair_id ' || p_repair_id
        );
        
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Заявка на ремонт не найдена' || p_repair_id
            );
    END start_repair;

    PROCEDURE complete_repair (
        p_repair_id      IN repair_orders.repair_id%TYPE,
        p_closed_by_staff_id IN staff.staff_id%TYPE,
        p_repair_result  IN repair_orders.repair_result%TYPE,
        p_repair_cost    IN repair_orders.repair_cost%TYPE,
        p_return_status  IN bicycles.status%TYPE DEFAULT 'AVAILABLE'
    ) IS
        l_status_repair repair_orders.status%TYPE;
        l_bicycle_id    bicycles.bicycle_id%TYPE;
    BEGIN

        IF p_return_status NOT IN (
            pkg_bicycle.c_status_available,
            pkg_bicycle.c_status_blocked
        ) THEN
            pkg_errors.raise_error(
                pkg_errors.c_invalid_status,
                'После ремонта разрешены только статусы AVAILABLE или BLOCKED'
            );
        END IF;

        SELECT bicycle_id,
               status
        INTO l_bicycle_id,
             l_status_repair
        FROM repair_orders
        WHERE repair_id = p_repair_id
        FOR UPDATE;

        IF l_status_repair != c_status_in_progress THEN
          pkg_errors.raise_error(
              pkg_errors.c_invalid_status,
              'Недопустимый статус' || l_status_repair
          );
        END IF;

        UPDATE repair_orders
        SET closed_by_staff_id = p_closed_by_staff_id,
            status        = c_status_completed,
            repair_result = p_repair_result,
            repair_cost   = p_repair_cost,
            completed_at  = SYSTIMESTAMP
        WHERE repair_id   = p_repair_id;


        pkg_bicycle.change_status(
            l_bicycle_id,
            p_return_status,
            'Окончание ремонтных работ',
            p_closed_by_staff_id,
            'complete_repair',
            p_repair_id
        );


        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'COMPLETE_REPAIR',
            p_entity_name => 'REPAIR_ORDERS',
            p_entity_id   => p_repair_id,
            p_old_data    => NULL,
            p_new_data    =>  'repair_id ' || p_repair_id
        );
        
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Заявка на ремонт не найдена' || p_repair_id
            );
    END complete_repair;

    PROCEDURE cancel_repair (
        p_repair_id  IN repair_orders.repair_id%TYPE,
        p_staff_id   IN staff.staff_id%TYPE,
        p_reason     IN VARCHAR2
    ) IS
        l_status_repair repair_orders.status%TYPE;
        l_bicycle_id    bicycles.bicycle_id%TYPE;
    BEGIN

        SELECT bicycle_id,
               status
        INTO l_bicycle_id,
             l_status_repair
        FROM repair_orders
        WHERE repair_id = p_repair_id
        FOR UPDATE;

        IF l_status_repair NOT IN (c_status_open, c_status_in_progress)  THEN
          pkg_errors.raise_error(
              pkg_errors.c_invalid_status,
              'Недопустимый статус для отмены' || l_status_repair
          );
        END IF;

        UPDATE repair_orders
        SET closed_by_staff_id = p_staff_id,
            status        = c_status_cancelled,
            repair_result = p_reason,
            completed_at  = SYSTIMESTAMP
        WHERE repair_id   = p_repair_id;


        pkg_audit.write_event(
            p_audit_type  => 'EVENT',
            p_action_code => 'CANCEL_REPAIR',
            p_entity_name => 'REPAIR_ORDERS',
            p_entity_id   => p_repair_id,
            p_old_data    => NULL,
            p_new_data    =>  'repair_id ' || p_repair_id
        );
        
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            pkg_errors.raise_error(
                pkg_errors.c_not_found,
                'Заявка на ремонт не найдены. Текущий статус = ' || p_repair_id
            );
    END cancel_repair;
END pkg_repair;
