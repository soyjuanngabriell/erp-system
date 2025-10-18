-- =====================================================
-- DIAGNÓSTICO DE ERRORES EN PAGOS Y FACTURACIÓN
-- =====================================================
-- Este script diagnostica los errores específicos que están
-- ocurriendo al registrar pagos y crear facturas

-- =====================================================
-- 1. VERIFICAR ESTRUCTURA DE TABLAS
-- =====================================================

SELECT '=== VERIFICACIÓN DE ESTRUCTURA DE TABLAS ===' as section;

-- Verificar tabla orders
SELECT 
    'orders' as tabla,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND table_schema = 'public'
AND column_name IN ('total_paid', 'pending_amount', 'payment_status', 'status', 'invoice_id', 'payment_amount')
ORDER BY ordinal_position;

-- Verificar tabla order_payments
SELECT 
    'order_payments' as tabla,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'order_payments' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- Verificar tabla invoices
SELECT 
    'invoices' as tabla,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'invoices' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- 2. VERIFICAR FUNCIONES DE PAGOS
-- =====================================================

SELECT '=== VERIFICACIÓN DE FUNCIONES ===' as section;

-- Verificar función update_order_payment_status
SELECT 
    routine_name,
    routine_type,
    data_type as return_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name = 'update_order_payment_status';

-- Verificar función convert_order_to_invoice
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name = 'convert_order_to_invoice';

-- =====================================================
-- 3. VERIFICAR TRIGGERS
-- =====================================================

SELECT '=== VERIFICACIÓN DE TRIGGERS ===' as section;

SELECT 
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('orders', 'order_payments')
AND event_object_schema = 'public';

-- =====================================================
-- 4. PROBAR INSERCIÓN DE PAGO MANUAL
-- =====================================================

SELECT '=== PRUEBA DE INSERCIÓN DE PAGO ===' as section;

-- Crear datos de prueba
INSERT INTO public.customers (name, rnc_cedula, email, phone) VALUES
('Cliente Prueba Pagos', '222222222', 'cliente@pagos.com', '809-222-2222')
ON CONFLICT (rnc_cedula) DO NOTHING;

INSERT INTO public.products (name, sku, price, stock, min_stock) VALUES
('Producto Prueba Pagos', 'PAGOS-002', 300.00, 100, 10)
ON CONFLICT (sku) DO NOTHING;

-- Probar inserción de pago
DO $$
DECLARE
    test_customer_id UUID;
    test_product_id UUID;
    test_user_id UUID;
    test_order_id UUID;
    test_payment_id UUID;
    test_total_paid DECIMAL(10,2);
    test_pending_amount DECIMAL(10,2);
    test_payment_status TEXT;
    error_message TEXT;
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '222222222' LIMIT 1;
    SELECT id INTO test_product_id FROM public.products WHERE sku = 'PAGOS-002' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    RAISE NOTICE '=== INICIANDO PRUEBA DE INSERCIÓN DE PAGO ===';
    RAISE NOTICE 'Cliente ID: %', test_customer_id;
    RAISE NOTICE 'Producto ID: %', test_product_id;
    RAISE NOTICE 'Usuario ID: %', test_user_id;

    -- 1. Crear orden
    BEGIN
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
            'Cliente Prueba Pagos',
            '222222222',
            'Pendiente',
            'BASICA',
            300.00,
            0.00,
            300.00,
            0.00,
            300.00,
            'Pendiente',
            test_user_id
        ) RETURNING id INTO test_order_id;

        RAISE NOTICE 'SUCCESS: Orden creada con ID: %', test_order_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR creando orden: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
            RETURN;
    END;

    -- 2. Crear item de orden
    BEGIN
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
            'Producto Prueba Pagos',
            'PAGOS-002',
            1,
            300.00,
            300.00
        );

        RAISE NOTICE 'SUCCESS: Item de orden creado';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR creando item de orden: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
    END;

    -- 3. Probar inserción de pago
    BEGIN
        INSERT INTO public.order_payments (
            order_id,
            amount,
            payment_method,
            notes,
            created_by
        ) VALUES (
            test_order_id,
            150.00,
            'Efectivo',
            'Pago de prueba',
            test_user_id
        ) RETURNING id INTO test_payment_id;

        RAISE NOTICE 'SUCCESS: Pago creado con ID: %', test_payment_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR creando pago: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
            RAISE NOTICE 'Detalles del error:';
            RAISE NOTICE '  order_id: %', test_order_id;
            RAISE NOTICE '  amount: 150.00';
            RAISE NOTICE '  payment_method: Efectivo';
            RAISE NOTICE '  created_by: %', test_user_id;
    END;

    -- 4. Probar función update_order_payment_status
    BEGIN
        PERFORM public.update_order_payment_status(test_order_id);
        RAISE NOTICE 'SUCCESS: Función update_order_payment_status ejecutada';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR ejecutando update_order_payment_status: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
    END;

    -- 5. Verificar estado después del pago
    BEGIN
        SELECT total_paid, pending_amount, payment_status INTO STRICT test_total_paid, test_pending_amount, test_payment_status
        FROM public.orders WHERE id = test_order_id;

        RAISE NOTICE 'Estado después del pago:';
        RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
        RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;
        RAISE NOTICE '  Estado de pago: %', test_payment_status;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR verificando estado: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
    END;

    -- Limpiar datos de prueba
    DELETE FROM public.order_payments WHERE order_id = test_order_id;
    DELETE FROM public.order_items WHERE order_id = test_order_id;
    DELETE FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE 'SUCCESS: Datos de prueba limpiados';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR GENERAL: %', SQLERRM;
        RAISE NOTICE 'Código de error: %', SQLSTATE;
        
        -- Limpiar en caso de error
        IF test_order_id IS NOT NULL THEN
            DELETE FROM public.order_payments WHERE order_id = test_order_id;
            DELETE FROM public.order_items WHERE order_id = test_order_id;
            DELETE FROM public.orders WHERE id = test_order_id;
        END IF;
END $$;

-- =====================================================
-- 5. PROBAR CREACIÓN DE FACTURA MANUAL
-- =====================================================

SELECT '=== PRUEBA DE CREACIÓN DE FACTURA ===' as section;

-- Probar creación de factura
DO $$
DECLARE
    test_customer_id UUID;
    test_product_id UUID;
    test_user_id UUID;
    test_invoice_id UUID;
    test_invoice_number TEXT;
    test_ncf TEXT;
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '222222222' LIMIT 1;
    SELECT id INTO test_product_id FROM public.products WHERE sku = 'PAGOS-002' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    RAISE NOTICE '=== INICIANDO PRUEBA DE CREACIÓN DE FACTURA ===';

    -- 1. Probar función get_next_invoice_number
    BEGIN
        SELECT public.get_next_invoice_number('BASICA') INTO test_invoice_number;
        RAISE NOTICE 'SUCCESS: Número de factura obtenido: %', test_invoice_number;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR obteniendo número de factura: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
            RETURN;
    END;

    -- 2. Probar función generate_ncf
    BEGIN
        SELECT public.generate_ncf('VALOR_FISCAL', 1) INTO test_ncf;
        RAISE NOTICE 'SUCCESS: NCF generado: %', test_ncf;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR generando NCF: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
    END;

    -- 3. Crear factura
    BEGIN
        INSERT INTO public.invoices (
            invoice_number,
            invoice_type,
            ncf,
            customer_name,
            customer_rnc,
            customer_email,
            customer_phone,
            subtotal,
            tax,
            discount,
            total,
            payment_method,
            notes,
            created_by
        ) VALUES (
            test_invoice_number,
            'BASICA',
            NULL,
            'Cliente Prueba Pagos',
            '222222222',
            'cliente@pagos.com',
            '809-222-2222',
            300.00,
            0.00,
            0.00,
            300.00,
            'Efectivo',
            'Factura de prueba',
            test_user_id
        ) RETURNING id INTO test_invoice_id;

        RAISE NOTICE 'SUCCESS: Factura creada con ID: %', test_invoice_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR creando factura: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
            RAISE NOTICE 'Detalles del error:';
            RAISE NOTICE '  invoice_number: %', test_invoice_number;
            RAISE NOTICE '  customer_name: Cliente Prueba Pagos';
            RAISE NOTICE '  created_by: %', test_user_id;
    END;

    -- 4. Crear item de factura
    BEGIN
        INSERT INTO public.invoice_items (
            invoice_id,
            product_id,
            product_name,
            product_sku,
            quantity,
            unit_price,
            subtotal
        ) VALUES (
            test_invoice_id,
            test_product_id,
            'Producto Prueba Pagos',
            'PAGOS-002',
            1,
            300.00,
            300.00
        );

        RAISE NOTICE 'SUCCESS: Item de factura creado';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR creando item de factura: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
    END;

    -- Limpiar datos de prueba
    IF test_invoice_id IS NOT NULL THEN
        DELETE FROM public.invoice_items WHERE invoice_id = test_invoice_id;
        DELETE FROM public.invoices WHERE id = test_invoice_id;
    END IF;

    RAISE NOTICE 'SUCCESS: Datos de prueba limpiados';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR GENERAL: %', SQLERRM;
        RAISE NOTICE 'Código de error: %', SQLSTATE;
        
        -- Limpiar en caso de error
        IF test_invoice_id IS NOT NULL THEN
            DELETE FROM public.invoice_items WHERE invoice_id = test_invoice_id;
            DELETE FROM public.invoices WHERE id = test_invoice_id;
        END IF;
END $$;

-- =====================================================
-- 6. LIMPIAR DATOS DE PRUEBA
-- =====================================================

DELETE FROM public.products WHERE sku = 'PAGOS-002';
DELETE FROM public.customers WHERE rnc_cedula = '222222222';

-- =====================================================
-- 7. RESUMEN DE DIAGNÓSTICO
-- =====================================================

SELECT '=== RESUMEN DE DIAGNÓSTICO ===' as section;

SELECT 
    'Tabla orders' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders' AND table_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Tabla order_payments' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_payments' AND table_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Tabla invoices' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoices' AND table_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Función update_order_payment_status' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_order_payment_status' AND routine_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Función convert_order_to_invoice' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'convert_order_to_invoice' AND routine_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Función get_next_invoice_number' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_next_invoice_number' AND routine_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Función generate_ncf' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'generate_ncf' AND routine_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado;

SELECT 'Diagnóstico completado. Revisa los mensajes de error arriba.' as result;
