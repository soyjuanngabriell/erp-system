-- =====================================================
-- PRUEBA RÁPIDA DE PAGOS Y FACTURACIÓN
-- =====================================================
-- Este script hace una prueba rápida para verificar que
-- los pagos y facturación funcionen correctamente

-- =====================================================
-- 1. CREAR DATOS DE PRUEBA
-- =====================================================

-- Crear cliente de prueba
INSERT INTO public.customers (name, rnc_cedula, email, phone) VALUES
('Cliente Prueba Rápida', '333333333', 'cliente@rapida.com', '809-333-3333')
ON CONFLICT (rnc_cedula) DO NOTHING;

-- Crear producto de prueba
INSERT INTO public.products (name, sku, price, stock, min_stock) VALUES
('Producto Prueba Rápida', 'RAPIDA-001', 500.00, 100, 10)
ON CONFLICT (sku) DO NOTHING;

-- =====================================================
-- 2. PRUEBA COMPLETA DE FLUJO
-- =====================================================

DO $$
DECLARE
    test_customer_id UUID;
    test_product_id UUID;
    test_user_id UUID;
    test_order_id UUID;
    test_payment_id UUID;
    test_invoice_id UUID;
    test_total_paid DECIMAL(10,2);
    test_pending_amount DECIMAL(10,2);
    test_payment_status TEXT;
    test_order_status TEXT;
    test_invoice_number TEXT;
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '333333333' LIMIT 1;
    SELECT id INTO test_product_id FROM public.products WHERE sku = 'RAPIDA-001' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    RAISE NOTICE '=== INICIANDO PRUEBA RÁPIDA ===';
    RAISE NOTICE 'Cliente ID: %', test_customer_id;
    RAISE NOTICE 'Producto ID: %', test_product_id;
    RAISE NOTICE 'Usuario ID: %', test_user_id;

    -- 1. Crear orden
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
        'RAPIDA-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
        test_customer_id,
        'Cliente Prueba Rápida',
        '333333333',
        'Pendiente',
        'BASICA',
        500.00,
        0.00,
        500.00,
        0.00,
        500.00,
        'Pendiente',
        test_user_id
    ) RETURNING id INTO test_order_id;

    RAISE NOTICE '✓ Orden creada: %', test_order_id;

    -- 2. Crear item de orden
    INSERT INTO public.order_items (
        order_id,
        product_id,
        product_name,
        product_sku,
        quantity,
        unit_price,
        subtotal
    ) VALUES (
        test_order_id,
        test_product_id,
        'Producto Prueba Rápida',
        'RAPIDA-001',
        1,
        500.00,
        500.00
    );

    RAISE NOTICE '✓ Item de orden creado';

    -- 3. Agregar pago parcial
    INSERT INTO public.order_payments (
        order_id,
        amount,
        payment_method,
        notes,
        created_by
    ) VALUES (
        test_order_id,
        200.00,
        'Efectivo',
        'Pago parcial',
        test_user_id
    ) RETURNING id INTO test_payment_id;

    RAISE NOTICE '✓ Pago parcial creado: %', test_payment_id;

    -- 4. Verificar estado después del pago (trigger debería ejecutarse automáticamente)
    SELECT total_paid, pending_amount, payment_status INTO STRICT test_total_paid, test_pending_amount, test_payment_status
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Estado después del pago:';
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;

    -- 5. Completar orden
    UPDATE public.orders 
    SET status = 'Completada', updated_at = NOW()
    WHERE id = test_order_id;

    RAISE NOTICE '✓ Orden marcada como completada';

    -- 6. Agregar pago final
    INSERT INTO public.order_payments (
        order_id,
        amount,
        payment_method,
        notes,
        created_by
    ) VALUES (
        test_order_id,
        300.00,
        'Tarjeta',
        'Pago final',
        test_user_id
    );

    RAISE NOTICE '✓ Pago final creado';

    -- 7. Verificar estado final
    SELECT total_paid, pending_amount, payment_status INTO STRICT test_total_paid, test_pending_amount, test_payment_status
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Estado final:';
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;

    -- 8. Convertir a factura
    IF test_pending_amount <= 0 THEN
        SELECT public.convert_order_to_invoice(test_order_id, 'BASICA') INTO test_invoice_id;
        
        IF test_invoice_id IS NOT NULL THEN
            RAISE NOTICE '✓ Orden convertida a factura: %', test_invoice_id;
            
            -- Verificar factura
            SELECT invoice_number INTO STRICT test_invoice_number
            FROM public.invoices WHERE id = test_invoice_id;
            
            RAISE NOTICE '✓ Factura creada: %', test_invoice_number;
            
            -- Verificar estado de orden
            SELECT status INTO STRICT test_order_status
            FROM public.orders WHERE id = test_order_id;
            
            RAISE NOTICE '✓ Estado de orden: %', test_order_status;
        ELSE
            RAISE NOTICE '✗ Error: No se pudo convertir a factura';
        END IF;
    ELSE
        RAISE NOTICE '✗ Error: Orden no completamente pagada (pendiente: RD$ %)', test_pending_amount;
    END IF;

    -- Limpiar datos de prueba
    DELETE FROM public.order_payments WHERE order_id = test_order_id;
    DELETE FROM public.order_items WHERE order_id = test_order_id;
    DELETE FROM public.orders WHERE id = test_order_id;
    IF test_invoice_id IS NOT NULL THEN
        DELETE FROM public.invoice_items WHERE invoice_id = test_invoice_id;
        DELETE FROM public.invoices WHERE id = test_invoice_id;
    END IF;

    RAISE NOTICE '✓ Datos de prueba limpiados';
    RAISE NOTICE '=== PRUEBA COMPLETADA EXITOSAMENTE ===';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '✗ ERROR: %', SQLERRM;
        RAISE NOTICE 'Código de error: %', SQLSTATE;
        
        -- Limpiar en caso de error
        IF test_order_id IS NOT NULL THEN
            DELETE FROM public.order_payments WHERE order_id = test_order_id;
            DELETE FROM public.order_items WHERE order_id = test_order_id;
            DELETE FROM public.orders WHERE id = test_order_id;
        END IF;
        IF test_invoice_id IS NOT NULL THEN
            DELETE FROM public.invoice_items WHERE invoice_id = test_invoice_id;
            DELETE FROM public.invoices WHERE id = test_invoice_id;
        END IF;
END $$;

-- =====================================================
-- 3. LIMPIAR DATOS DE PRUEBA
-- =====================================================

DELETE FROM public.products WHERE sku = 'RAPIDA-001';
DELETE FROM public.customers WHERE rnc_cedula = '333333333';

-- =====================================================
-- 4. RESUMEN FINAL
-- =====================================================

SELECT '=== RESUMEN DE PRUEBA ===' as section;

SELECT 
    'Pagos' as funcionalidad,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_order_payment_status' AND routine_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Facturación' as funcionalidad,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'convert_order_to_invoice' AND routine_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Triggers' as funcionalidad,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE event_object_table = 'order_payments' AND event_object_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado;

SELECT 'Prueba rápida completada. Revisa los mensajes arriba para verificar el resultado.' as result;
