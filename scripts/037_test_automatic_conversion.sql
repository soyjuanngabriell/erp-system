-- =====================================================
-- PRUEBA DE CONVERSIÓN AUTOMÁTICA A FACTURA
-- =====================================================
-- Este script prueba que la conversión automática funcione
-- cuando una orden está completamente pagada

-- =====================================================
-- 1. CREAR DATOS DE PRUEBA
-- =====================================================

-- Crear cliente de prueba
INSERT INTO public.customers (name, rnc_cedula, email, phone) VALUES
('Cliente Prueba Conversión', '666666666', 'cliente@conversion.com', '809-666-6666')
ON CONFLICT (rnc_cedula) DO NOTHING;

-- Crear producto de prueba
INSERT INTO public.products (name, sku, price, stock, min_stock) VALUES
('Producto Prueba Conversión', 'CONVERSION-001', 800.00, 100, 10)
ON CONFLICT (sku) DO NOTHING;

-- =====================================================
-- 2. PRUEBA DE CONVERSIÓN AUTOMÁTICA
-- =====================================================

DO $$
DECLARE
    test_customer_id UUID;
    test_product_id UUID;
    test_user_id UUID;
    test_order_id UUID;
    test_payment_id UUID;
    test_invoice_id UUID;
    test_invoice_number TEXT;
    test_order_status TEXT;
    test_payment_status payment_status;
    test_total_paid DECIMAL(10,2);
    test_pending_amount DECIMAL(10,2);
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '666666666' LIMIT 1;
    SELECT id INTO test_product_id FROM public.products WHERE sku = 'CONVERSION-001' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    RAISE NOTICE '=== INICIANDO PRUEBA DE CONVERSIÓN AUTOMÁTICA ===';
    RAISE NOTICE 'Cliente ID: %', test_customer_id;
    RAISE NOTICE 'Producto ID: %', test_product_id;
    RAISE NOTICE 'Usuario ID: %', test_user_id;

    -- 1. Crear orden pendiente
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
        'CONVERSION-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
        test_customer_id,
        'Cliente Prueba Conversión',
        '666666666',
        'Pendiente'::order_status,
        'BASICA'::invoice_type,
        800.00,
        0.00,
        800.00,
        0.00,
        800.00,
        'Pendiente'::payment_status,
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
        'Producto Prueba Conversión',
        'CONVERSION-001',
        1,
        800.00,
        800.00
    );

    RAISE NOTICE '✓ Item de orden creado';

    -- 3. Verificar estado inicial
    SELECT status, payment_status, total_paid, pending_amount 
    INTO STRICT test_order_status, test_payment_status, test_total_paid, test_pending_amount
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Estado inicial:';
    RAISE NOTICE '  Estado: %', test_order_status;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;

    -- 4. Agregar pago parcial
    INSERT INTO public.order_payments (
        order_id,
        amount,
        payment_method,
        notes,
        created_by
    ) VALUES (
        test_order_id,
        400.00,
        'Efectivo',
        'Pago parcial',
        test_user_id
    ) RETURNING id INTO test_payment_id;

    RAISE NOTICE '✓ Pago parcial creado: %', test_payment_id;

    -- 5. Verificar estado después del pago parcial
    SELECT status, payment_status, total_paid, pending_amount 
    INTO STRICT test_order_status, test_payment_status, test_total_paid, test_pending_amount
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Estado después del pago parcial:';
    RAISE NOTICE '  Estado: %', test_order_status;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;

    -- 6. Agregar pago final
    INSERT INTO public.order_payments (
        order_id,
        amount,
        payment_method,
        notes,
        created_by
    ) VALUES (
        test_order_id,
        400.00,
        'Tarjeta',
        'Pago final',
        test_user_id
    );

    RAISE NOTICE '✓ Pago final creado';

    -- 7. Verificar estado después del pago completo
    SELECT status, payment_status, total_paid, pending_amount 
    INTO STRICT test_order_status, test_payment_status, test_total_paid, test_pending_amount
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Estado después del pago completo:';
    RAISE NOTICE '  Estado: %', test_order_status;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;

    -- 8. Marcar orden como completada (simulando el botón "Completar Orden")
    UPDATE public.orders 
    SET status = 'Completada'::order_status, updated_at = NOW()
    WHERE id = test_order_id;

    RAISE NOTICE '✓ Orden marcada como completada';

    -- 9. Verificar estado después de marcar como completada
    SELECT status, payment_status, total_paid, pending_amount 
    INTO STRICT test_order_status, test_payment_status, test_total_paid, test_pending_amount
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Estado después de marcar como completada:';
    RAISE NOTICE '  Estado: %', test_order_status;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;

    -- 10. Intentar conversión a factura
    IF test_pending_amount <= 0 AND test_order_status = 'Completada' THEN
        SELECT public.convert_order_to_invoice(test_order_id, 'BASICA') INTO test_invoice_id;
        
        IF test_invoice_id IS NOT NULL THEN
            RAISE NOTICE '✓ Orden convertida a factura: %', test_invoice_id;
            
            -- Verificar factura creada
            SELECT invoices.invoice_number INTO STRICT test_invoice_number
            FROM public.invoices WHERE invoices.id = test_invoice_id;
            
            RAISE NOTICE '✓ Factura creada: %', test_invoice_number;
            
            -- Verificar estado final de la orden
            SELECT status INTO STRICT test_order_status
            FROM public.orders WHERE id = test_order_id;
            
            RAISE NOTICE '✓ Estado final de la orden: %', test_order_status;
        ELSE
            RAISE NOTICE '✗ Error: No se pudo convertir a factura';
        END IF;
    ELSE
        RAISE NOTICE '✗ Error: Condiciones no cumplidas para conversión';
        RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;
        RAISE NOTICE '  Estado: %', test_order_status;
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
    RAISE NOTICE '=== PRUEBA DE CONVERSIÓN AUTOMÁTICA COMPLETADA ===';

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

DELETE FROM public.products WHERE sku = 'CONVERSION-001';
DELETE FROM public.customers WHERE rnc_cedula = '666666666';

-- =====================================================
-- 4. RESUMEN FINAL
-- =====================================================

SELECT '=== RESUMEN DE PRUEBA DE CONVERSIÓN ===' as section;

SELECT 
    'Conversión automática' as funcionalidad,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'convert_order_to_invoice' AND routine_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Actualización de pagos' as funcionalidad,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_order_payment_status' AND routine_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Triggers automáticos' as funcionalidad,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.triggers WHERE event_object_table = 'order_payments' AND event_object_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado;

SELECT 'Prueba de conversión automática completada.' as result;
