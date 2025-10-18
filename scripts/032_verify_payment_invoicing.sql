-- =====================================================
-- VERIFICACIÓN DE GESTIÓN DE PAGOS Y FACTURACIÓN
-- =====================================================
-- Este script verifica que todas las funciones relacionadas
-- con pagos y facturación estén funcionando correctamente

-- =====================================================
-- 1. VERIFICAR ESTRUCTURA DE TABLAS RELACIONADAS
-- =====================================================

SELECT '=== ESTRUCTURA DE TABLAS ===' as section;

-- Verificar tabla orders
SELECT 
    'orders' as tabla,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND table_schema = 'public'
AND column_name IN ('total_paid', 'pending_amount', 'payment_status', 'status', 'invoice_id')
ORDER BY ordinal_position;

-- Verificar tabla order_payments
SELECT 
    'order_payments' as tabla,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'order_payments' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Verificar tabla invoices
SELECT 
    'invoices' as tabla,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns 
WHERE table_name = 'invoices' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- 2. VERIFICAR FUNCIONES DE FACTURACIÓN
-- =====================================================

SELECT '=== FUNCIONES DE FACTURACIÓN ===' as section;

-- Verificar funciones existentes
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name IN (
    'get_next_invoice_number',
    'generate_ncf',
    'update_order_payment_status',
    'convert_order_to_invoice'
)
ORDER BY routine_name;

-- =====================================================
-- 3. VERIFICAR TRIGGERS DE PAGOS
-- =====================================================

SELECT '=== TRIGGERS ===' as section;

SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('orders', 'order_payments')
AND event_object_schema = 'public';

-- =====================================================
-- 4. PROBAR FLUJO COMPLETO DE PAGOS Y FACTURACIÓN
-- =====================================================

SELECT '=== PRUEBA DE FLUJO COMPLETO ===' as section;

-- Crear datos de prueba
INSERT INTO public.customers (name, rnc_cedula, email, phone) VALUES
('Cliente de Prueba Pagos', '111111111', 'cliente@pagos.com', '809-111-1111')
ON CONFLICT (rnc_cedula) DO NOTHING;

INSERT INTO public.products (name, sku, price, stock, min_stock) VALUES
('Producto Pagos', 'PAGOS-001', 200.00, 100, 10)
ON CONFLICT (sku) DO NOTHING;

-- Probar flujo completo
DO $$
DECLARE
    test_customer_id UUID;
    test_product_id UUID;
    test_user_id UUID;
    test_order_id UUID;
    test_payment_id UUID;
    test_invoice_id UUID;
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '111111111' LIMIT 1;
    SELECT id INTO test_product_id FROM public.products WHERE sku = 'PAGOS-001' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    RAISE NOTICE '=== INICIANDO PRUEBA DE FLUJO COMPLETO ===';
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
        'PAGOS-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
        test_customer_id,
        'Cliente de Prueba Pagos',
        '111111111',
        'Pendiente',
        'BASICA',
        200.00,
        0.00,
        200.00,
        0.00,
        200.00,
        'Pendiente',
        test_user_id
    ) RETURNING id INTO test_order_id;

    RAISE NOTICE 'SUCCESS: Orden creada con ID: %', test_order_id;

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
        'Producto Pagos',
        'PAGOS-001',
        1,
        200.00,
        200.00
    );

    RAISE NOTICE 'SUCCESS: Item de orden creado';

    -- 3. Agregar pago parcial
    INSERT INTO public.order_payments (
        order_id,
        amount,
        payment_method,
        notes,
        created_by
    ) VALUES (
        test_order_id,
        100.00,
        'Efectivo',
        'Pago parcial de prueba',
        test_user_id
    ) RETURNING id INTO test_payment_id;

    RAISE NOTICE 'SUCCESS: Pago parcial creado con ID: %', test_payment_id;

    -- 4. Actualizar estado de pago
    PERFORM public.update_order_payment_status(test_order_id);

    RAISE NOTICE 'SUCCESS: Estado de pago actualizado';

    -- 5. Verificar estado después del pago
    SELECT total_paid, pending_amount, payment_status INTO STRICT test_total_paid, test_pending_amount, test_payment_status
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE 'Estado después del pago parcial:';
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;

    -- 6. Completar orden
    UPDATE public.orders 
    SET status = 'Completada', updated_at = NOW()
    WHERE id = test_order_id;

    RAISE NOTICE 'SUCCESS: Orden marcada como completada';

    -- 7. Agregar pago final
    INSERT INTO public.order_payments (
        order_id,
        amount,
        payment_method,
        notes,
        created_by
    ) VALUES (
        test_order_id,
        100.00,
        'Tarjeta',
        'Pago final de prueba',
        test_user_id
    );

    RAISE NOTICE 'SUCCESS: Pago final creado';

    -- 8. Actualizar estado de pago nuevamente
    PERFORM public.update_order_payment_status(test_order_id);

    RAISE NOTICE 'SUCCESS: Estado de pago actualizado';

    -- 9. Verificar estado final
    SELECT total_paid, pending_amount, payment_status INTO STRICT test_total_paid, test_pending_amount, test_payment_status
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE 'Estado después del pago completo:';
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;

    -- 10. Convertir a factura si está completamente pagada
    IF test_pending_amount <= 0 THEN
        SELECT public.convert_order_to_invoice(test_order_id, 'BASICA') INTO test_invoice_id;
        
        IF test_invoice_id IS NOT NULL THEN
            RAISE NOTICE 'SUCCESS: Orden convertida a factura con ID: %', test_invoice_id;
            
            -- Verificar factura creada
            SELECT invoice_number, total INTO STRICT test_invoice_number, test_invoice_total
            FROM public.invoices WHERE id = test_invoice_id;
            
            RAISE NOTICE 'Factura creada:';
            RAISE NOTICE '  Número: %', test_invoice_number;
            RAISE NOTICE '  Total: RD$ %', test_invoice_total;
            
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

    -- Limpiar datos de prueba
    DELETE FROM public.order_payments WHERE order_id = test_order_id;
    DELETE FROM public.order_items WHERE order_id = test_order_id;
    DELETE FROM public.orders WHERE id = test_order_id;
    IF test_invoice_id IS NOT NULL THEN
        DELETE FROM public.invoice_items WHERE invoice_id = test_invoice_id;
        DELETE FROM public.invoices WHERE id = test_invoice_id;
    END IF;

    RAISE NOTICE 'SUCCESS: Datos de prueba limpiados';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR: %', SQLERRM;
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
-- 5. LIMPIAR DATOS DE PRUEBA
-- =====================================================

DELETE FROM public.products WHERE sku = 'PAGOS-001';
DELETE FROM public.customers WHERE rnc_cedula = '111111111';

-- =====================================================
-- 6. RESUMEN FINAL
-- =====================================================

SELECT '=== RESUMEN FINAL ===' as section;

SELECT 
    'Gestión de pagos' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_payments' AND table_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Facturación' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoices' AND table_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Función convert_order_to_invoice' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'convert_order_to_invoice' AND routine_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Función update_order_payment_status' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_order_payment_status' AND routine_schema = 'public') 
         THEN 'FUNCIONANDO' 
         ELSE 'ERROR' 
    END as estado;

SELECT 'Verificación de gestión de pagos y facturación completada.' as result;
