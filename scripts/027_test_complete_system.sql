    -- =====================================================
    -- SCRIPT DE PRUEBA COMPLETA DEL SISTEMA
    -- =====================================================
    -- Este script prueba todo el flujo: crear orden → agregar pagos → convertir a factura

    -- =====================================================
    -- 1. LIMPIAR DATOS DE PRUEBA ANTERIORES
    -- =====================================================

    -- Eliminar datos de prueba anteriores
    DELETE FROM public.order_payments WHERE order_id IN (
        SELECT id FROM public.orders WHERE order_number LIKE 'TEST-%'
    );
    DELETE FROM public.order_items WHERE order_id IN (
        SELECT id FROM public.orders WHERE order_number LIKE 'TEST-%'
    );
    DELETE FROM public.orders WHERE order_number LIKE 'TEST-%';
    DELETE FROM public.invoices WHERE invoice_number LIKE 'TEST-%';
    DELETE FROM public.invoice_items WHERE invoice_id IN (
        SELECT id FROM public.invoices WHERE invoice_number LIKE 'TEST-%'
    );

    -- =====================================================
    -- 2. CREAR DATOS DE PRUEBA
    -- =====================================================

    -- Crear cliente de prueba
    INSERT INTO public.customers (name, rnc_cedula, email, phone) VALUES
    ('Cliente de Prueba', '123456789', 'cliente@test.com', '809-123-4567')
    ON CONFLICT (rnc_cedula) DO NOTHING;

    -- Crear productos de prueba
    INSERT INTO public.products (name, sku, price, stock, min_stock) VALUES
    ('Producto A', 'SKU-A', 100.00, 50, 5),
    ('Producto B', 'SKU-B', 200.00, 30, 3),
    ('Producto C', 'SKU-C', 150.00, 40, 4)
    ON CONFLICT (sku) DO NOTHING;

    -- Obtener IDs
    DO $$
    DECLARE
        test_customer_id UUID;
        test_product_a_id UUID;
        test_product_b_id UUID;
        test_product_c_id UUID;
        test_user_id UUID;
        test_order_id UUID;
        test_invoice_id UUID;
    BEGIN
        -- Obtener IDs
        SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '123456789' LIMIT 1;
        SELECT id INTO test_product_a_id FROM public.products WHERE sku = 'SKU-A' LIMIT 1;
        SELECT id INTO test_product_b_id FROM public.products WHERE sku = 'SKU-B' LIMIT 1;
        SELECT id INTO test_product_c_id FROM public.products WHERE sku = 'SKU-C' LIMIT 1;
        SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

        RAISE NOTICE '=== INICIANDO PRUEBA COMPLETA ===';
        RAISE NOTICE 'Cliente ID: %', test_customer_id;
        RAISE NOTICE 'Producto A ID: %', test_product_a_id;
        RAISE NOTICE 'Producto B ID: %', test_product_b_id;
        RAISE NOTICE 'Producto C ID: %', test_product_c_id;
        RAISE NOTICE 'Usuario ID: %', test_user_id;

        -- =====================================================
        -- 3. CREAR ORDEN DE PRUEBA
        -- =====================================================

        INSERT INTO public.orders (
            order_number,
            customer_id,
            customer_name,
            customer_rnc,
            status,
            invoice_type,
            subtotal,
            tax,
            total,
            total_paid,
            pending_amount,
            payment_status,
            created_by
        ) VALUES (
            'TEST-ORDER-001',
            test_customer_id,
            'Cliente de Prueba',
            '123456789',
            'Pendiente',
            'BASICA',
            450.00, -- 100 + 200 + 150
            0.00,   -- Sin ITBIS para básica
            450.00,
            0.00,
            450.00,
            'Pendiente',
            test_user_id
        ) RETURNING id INTO test_order_id;

        RAISE NOTICE 'Orden creada con ID: %', test_order_id;

        -- Crear items de la orden
        INSERT INTO public.order_items (order_id, product_id, product_name, product_sku, quantity, unit_price, subtotal) VALUES
        (test_order_id, test_product_a_id, 'Producto A', 'SKU-A', 1, 100.00, 100.00),
        (test_product_b_id, test_product_b_id, 'Producto B', 'SKU-B', 1, 200.00, 200.00),
        (test_order_id, test_product_c_id, 'Producto C', 'SKU-C', 1, 150.00, 150.00);

        RAISE NOTICE 'Items de orden creados';

        -- =====================================================
        -- 4. SIMULAR PAGO PARCIAL
        -- =====================================================

        -- Agregar pago parcial
        INSERT INTO public.order_payments (order_id, amount, payment_method, notes, created_by) VALUES
        (test_order_id, 200.00, 'Efectivo', 'Pago parcial inicial', test_user_id);

        -- Actualizar estado de pago
        PERFORM public.update_order_payment_status(test_order_id);

        RAISE NOTICE 'Pago parcial de RD$ 200.00 registrado';

        -- Verificar estado
        SELECT pending_amount, payment_status INTO STRICT test_pending_amount, test_payment_status
        FROM public.orders WHERE id = test_order_id;

        RAISE NOTICE 'Estado después del pago parcial:';
        RAISE NOTICE '  Monto pendiente: RD$ %', test_pending_amount;
        RAISE NOTICE '  Estado de pago: %', test_payment_status;

        -- =====================================================
        -- 5. COMPLETAR ORDEN
        -- =====================================================

        UPDATE public.orders 
        SET status = 'Completada', updated_at = NOW()
        WHERE id = test_order_id;

        RAISE NOTICE 'Orden marcada como completada';

        -- =====================================================
        -- 6. COMPLETAR PAGO
        -- =====================================================

        -- Agregar pago restante
        INSERT INTO public.order_payments (order_id, amount, payment_method, notes, created_by) VALUES
        (test_order_id, 250.00, 'Tarjeta', 'Pago final', test_user_id);

        -- Actualizar estado de pago
        PERFORM public.update_order_payment_status(test_order_id);

        RAISE NOTICE 'Pago final de RD$ 250.00 registrado';

        -- Verificar estado final
        SELECT pending_amount, payment_status INTO STRICT test_pending_amount, test_payment_status
        FROM public.orders WHERE id = test_order_id;

        RAISE NOTICE 'Estado después del pago completo:';
        RAISE NOTICE '  Monto pendiente: RD$ %', test_pending_amount;
        RAISE NOTICE '  Estado de pago: %', test_payment_status;

        -- =====================================================
        -- 7. CONVERTIR A FACTURA
        -- =====================================================

        IF test_pending_amount <= 0 THEN
            SELECT public.convert_order_to_invoice(test_order_id, 'BASICA') INTO test_invoice_id;
            
            IF test_invoice_id IS NOT NULL THEN
                RAISE NOTICE 'Orden convertida a factura con ID: %', test_invoice_id;
                
                -- Verificar factura creada
                SELECT invoice_number, total INTO STRICT test_invoice_number, test_invoice_total
                FROM public.invoices WHERE id = test_invoice_id;
                
                RAISE NOTICE 'Factura creada:';
                RAISE NOTICE '  Número: %', test_invoice_number;
                RAISE NOTICE '  Total: RD$ %', test_invoice_total;
                
                -- Verificar items de factura
                SELECT COUNT(*) INTO STRICT test_invoice_items_count
                FROM public.invoice_items WHERE invoice_id = test_invoice_id;
                
                RAISE NOTICE '  Items de factura: %', test_invoice_items_count;
                
                -- Verificar estado de orden actualizado
                SELECT status INTO STRICT test_order_status
                FROM public.orders WHERE id = test_order_id;
                
                RAISE NOTICE 'Estado de orden después de conversión: %', test_order_status;
            ELSE
                RAISE NOTICE 'ERROR: No se pudo convertir la orden a factura';
            END IF;
        ELSE
            RAISE NOTICE 'ERROR: La orden no está completamente pagada (pendiente: RD$ %)', test_pending_amount;
        END IF;

        -- =====================================================
        -- 8. VERIFICAR MOVIMIENTOS DE STOCK
        -- =====================================================

        RAISE NOTICE '=== VERIFICANDO MOVIMIENTOS DE STOCK ===';
        
        -- Verificar que se crearon movimientos de stock
        SELECT COUNT(*) INTO STRICT test_stock_movements_count
        FROM public.stock_movements 
        WHERE reference_id = test_order_id AND reference_type = 'order';
        
        RAISE NOTICE 'Movimientos de stock creados: %', test_stock_movements_count;
        
        -- Verificar stock actual de productos
        SELECT stock INTO STRICT test_product_a_stock FROM public.products WHERE id = test_product_a_id;
        SELECT stock INTO STRICT test_product_b_stock FROM public.products WHERE id = test_product_b_id;
        SELECT stock INTO STRICT test_product_c_stock FROM public.products WHERE id = test_product_c_id;
        
        RAISE NOTICE 'Stock actual de productos:';
        RAISE NOTICE '  Producto A: %', test_product_a_stock;
        RAISE NOTICE '  Producto B: %', test_product_b_stock;
        RAISE NOTICE '  Producto C: %', test_product_c_stock;

        RAISE NOTICE '=== PRUEBA COMPLETA FINALIZADA ===';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR EN LA PRUEBA: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
    END $$;

    -- =====================================================
    -- 9. MOSTRAR RESUMEN FINAL
    -- =====================================================

    SELECT '=== RESUMEN DE LA PRUEBA ===' as section;

    -- Mostrar órdenes de prueba
    SELECT 
        'Órdenes de prueba' as tipo,
        COUNT(*) as cantidad
    FROM public.orders 
    WHERE order_number LIKE 'TEST-%'
    UNION ALL
    SELECT 
        'Facturas de prueba' as tipo,
        COUNT(*) as cantidad
    FROM public.invoices 
    WHERE invoice_number LIKE 'TEST-%'
    UNION ALL
    SELECT 
        'Pagos de prueba' as tipo,
        COUNT(*) as cantidad
    FROM public.order_payments 
    WHERE order_id IN (SELECT id FROM public.orders WHERE order_number LIKE 'TEST-%')
    UNION ALL
    SELECT 
        'Movimientos de stock' as tipo,
        COUNT(*) as cantidad
    FROM public.stock_movements 
    WHERE reference_id IN (SELECT id FROM public.orders WHERE order_number LIKE 'TEST-%');

    -- Mostrar estado final de la orden de prueba
    SELECT 
        order_number,
        status,
        payment_status,
        total,
        total_paid,
        pending_amount,
        invoice_id
    FROM public.orders 
    WHERE order_number LIKE 'TEST-%';

    -- Mostrar factura generada
    SELECT 
        invoice_number,
        invoice_type,
        total,
        order_id
    FROM public.invoices 
    WHERE invoice_number LIKE 'TEST-%';

    SELECT 'Prueba del sistema completada exitosamente.' as result;
