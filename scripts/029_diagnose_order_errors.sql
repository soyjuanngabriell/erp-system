-- =====================================================
-- DIAGNÓSTICO DE ERRORES EN CREACIÓN DE ÓRDENES
-- =====================================================
-- Este script diagnostica problemas específicos con la creación de órdenes

-- =====================================================
-- 1. VERIFICAR ESTRUCTURA DE LA TABLA ORDERS
-- =====================================================

SELECT '=== ESTRUCTURA DE TABLA ORDERS ===' as section;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- 2. VERIFICAR TIPOS DE DATOS PERSONALIZADOS
-- =====================================================

SELECT '=== TIPOS PERSONALIZADOS ===' as section;

-- Verificar enum order_status
SELECT 
    'order_status' as tipo,
    enumlabel as valor
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')
ORDER BY enumsortorder;

-- Verificar enum invoice_type
SELECT 
    'invoice_type' as tipo,
    enumlabel as valor
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'invoice_type')
ORDER BY enumsortorder;

-- Verificar enum payment_status
SELECT 
    'payment_status' as tipo,
    enumlabel as valor
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')
ORDER BY enumsortorder;

-- Verificar enum payment_method
SELECT 
    'payment_method' as tipo,
    enumlabel as valor
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')
ORDER BY enumsortorder;

-- =====================================================
-- 3. VERIFICAR CONSTRAINTS Y FOREIGN KEYS
-- =====================================================

SELECT '=== CONSTRAINTS Y FOREIGN KEYS ===' as section;

-- Mostrar constraints de la tabla orders
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
LEFT JOIN information_schema.constraint_column_usage ccu 
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.table_name = 'orders'
AND tc.table_schema = 'public';

-- =====================================================
-- 4. PROBAR INSERCIÓN DE ORDEN DE PRUEBA
-- =====================================================

SELECT '=== PRUEBA DE INSERCIÓN DE ORDEN ===' as section;

-- Crear datos de prueba necesarios
INSERT INTO public.customers (name, rnc_cedula, email, phone) VALUES
('Cliente de Prueba', '123456789', 'cliente@test.com', '809-123-4567')
ON CONFLICT (rnc_cedula) DO NOTHING;

INSERT INTO public.products (name, sku, price, stock, min_stock) VALUES
('Producto de Prueba', 'TEST-PROD-001', 100.00, 50, 5)
ON CONFLICT (sku) DO NOTHING;

-- Obtener IDs necesarios
DO $$
DECLARE
    test_customer_id UUID;
    test_product_id UUID;
    test_user_id UUID;
    test_order_id UUID;
    test_order_item_id UUID;
    test_payment_id UUID;
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '123456789' LIMIT 1;
    SELECT id INTO test_product_id FROM public.products WHERE sku = 'TEST-PROD-001' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    RAISE NOTICE '=== INICIANDO PRUEBA DE ORDEN ===';
    RAISE NOTICE 'Cliente ID: %', test_customer_id;
    RAISE NOTICE 'Producto ID: %', test_product_id;
    RAISE NOTICE 'Usuario ID: %', test_user_id;

    -- Probar inserción de orden
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
            discount,
            total,
            total_paid,
            pending_amount,
            payment_status,
            notes,
            created_by
        ) VALUES (
            'TEST-ORDER-' || EXTRACT(EPOCH FROM NOW())::TEXT,
            test_customer_id,
            'Cliente de Prueba',
            '123456789',
            'Pendiente',
            'BASICA',
            100.00,
            0.00,
            0.00,
            100.00,
            0.00,
            100.00,
            'Pendiente',
            'Orden de prueba',
            test_user_id
        ) RETURNING id INTO test_order_id;

        RAISE NOTICE 'SUCCESS: Orden creada con ID: %', test_order_id;

        -- Probar inserción de order_item
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
            'Producto de Prueba',
            'TEST-PROD-001',
            1,
            100.00,
            100.00
        ) RETURNING id INTO test_order_item_id;

        RAISE NOTICE 'SUCCESS: Order item creado con ID: %', test_order_item_id;

        -- Probar inserción de pago
        INSERT INTO public.order_payments (
            order_id,
            amount,
            payment_method,
            notes,
            created_by
        ) VALUES (
            test_order_id,
            50.00,
            'Efectivo',
            'Pago parcial de prueba',
            test_user_id
        ) RETURNING id INTO test_payment_id;

        RAISE NOTICE 'SUCCESS: Pago creado con ID: %', test_payment_id;

        -- Limpiar datos de prueba
        DELETE FROM public.order_payments WHERE id = test_payment_id;
        DELETE FROM public.order_items WHERE id = test_order_item_id;
        DELETE FROM public.orders WHERE id = test_order_id;

        RAISE NOTICE 'SUCCESS: Datos de prueba limpiados';

    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR: %', SQLERRM;
            RAISE NOTICE 'Código de error: %', SQLSTATE;
            
            -- Limpiar en caso de error
            IF test_order_id IS NOT NULL THEN
                DELETE FROM public.order_items WHERE order_id = test_order_id;
                DELETE FROM public.order_payments WHERE order_id = test_order_id;
                DELETE FROM public.orders WHERE id = test_order_id;
            END IF;
    END;

END $$;

-- =====================================================
-- 5. VERIFICAR FUNCIONES DE BASE DE DATOS
-- =====================================================

SELECT '=== FUNCIONES DE BASE DE DATOS ===' as section;

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
    'convert_order_to_invoice',
    'update_product_stock'
)
ORDER BY routine_name;

-- =====================================================
-- 6. VERIFICAR TRIGGERS
-- =====================================================

SELECT '=== TRIGGERS ===' as section;

SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'orders'
AND event_object_schema = 'public';

-- =====================================================
-- 7. LIMPIAR DATOS DE PRUEBA
-- =====================================================

DELETE FROM public.products WHERE sku = 'TEST-PROD-001';
DELETE FROM public.customers WHERE rnc_cedula = '123456789';

-- =====================================================
-- 8. RESUMEN FINAL
-- =====================================================

SELECT '=== RESUMEN FINAL ===' as section;

SELECT 
    'Tabla orders' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders' AND table_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Tabla order_items' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'order_items' AND table_schema = 'public') 
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
    'Enum order_status' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_status') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Enum payment_status' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado;

SELECT 'Diagnóstico de errores en órdenes completado.' as result;
