-- Script de diagnóstico específico para problemas de conversión a factura
-- Este script ayuda a identificar problemas específicos en la función convert_order_to_invoice

-- 1. Verificar que todas las funciones existen y funcionan
SELECT '=== VERIFICACIÓN DE FUNCIONES ===' as section;

-- Probar función get_next_invoice_number_by_type
DO $$
DECLARE
    test_number TEXT;
    test_error TEXT;
BEGIN
    BEGIN
        SELECT public.get_next_invoice_number_by_type('BASICA') INTO test_number;
        RAISE NOTICE 'SUCCESS: get_next_invoice_number_by_type funciona. Número generado: %', test_number;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR: get_next_invoice_number_by_type falló: %', SQLERRM;
    END;
END $$;

-- Probar función generate_ncf
DO $$
DECLARE
    test_ncf TEXT;
BEGIN
    BEGIN
        SELECT public.generate_ncf('VALOR_FISCAL', 1) INTO test_ncf;
        RAISE NOTICE 'SUCCESS: generate_ncf funciona. NCF generado: %', test_ncf;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR: generate_ncf falló: %', SQLERRM;
    END;
END $$;

-- 2. Verificar estructura de tablas críticas
SELECT '=== ESTRUCTURA DE TABLAS ===' as section;

-- Verificar tabla orders
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND column_name IN ('id', 'customer_name', 'customer_rnc', 'subtotal', 'tax', 'total', 'invoice_type', 'created_by')
ORDER BY ordinal_position;

-- Verificar tabla invoices
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'invoices' 
AND column_name IN ('id', 'invoice_number', 'invoice_type', 'ncf', 'order_id', 'customer_name', 'subtotal', 'tax', 'total', 'created_by')
ORDER BY ordinal_position;

-- Verificar tabla invoice_items
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'invoice_items' 
AND column_name IN ('id', 'invoice_id', 'product_id', 'product_name', 'product_sku', 'quantity', 'unit_price', 'subtotal')
ORDER BY ordinal_position;

-- 3. Verificar datos de prueba
SELECT '=== DATOS DE PRUEBA ===' as section;

-- Buscar órdenes completadas sin factura
SELECT 
    o.id,
    o.order_number,
    o.status,
    o.invoice_type,
    o.total,
    o.payment_amount,
    o.pending_amount,
    o.invoice_id,
    COUNT(oi.id) as item_count
FROM public.orders o
LEFT JOIN public.order_items oi ON o.id = oi.order_id
WHERE o.status = 'Completado' 
AND o.invoice_id IS NULL
GROUP BY o.id, o.order_number, o.status, o.invoice_type, o.total, o.payment_amount, o.pending_amount, o.invoice_id
ORDER BY o.created_at DESC
LIMIT 5;

-- 4. Probar conversión manual con una orden específica
SELECT '=== PRUEBA DE CONVERSIÓN MANUAL ===' as section;

-- Crear una orden de prueba si no existe
INSERT INTO public.orders (
    order_number,
    customer_name,
    customer_rnc,
    status,
    invoice_type,
    subtotal,
    tax,
    discount,
    total,
    payment_amount,
    pending_amount,
    created_by
) VALUES (
    'TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
    'Cliente de Prueba',
    '123456789',
    'Completado',
    'BASICA',
    1000.00,
    0.00,
    0.00,
    1000.00,
    1000.00,
    0.00,
    (SELECT id FROM public.profiles LIMIT 1)
) ON CONFLICT (order_number) DO NOTHING
RETURNING id, order_number;

-- Crear items de prueba para la orden
INSERT INTO public.order_items (
    order_id,
    product_name,
    product_sku,
    quantity,
    unit_price,
    subtotal
) 
SELECT 
    o.id,
    'Producto de Prueba',
    'TEST-001',
    1,
    1000.00,
    1000.00
FROM public.orders o
WHERE o.order_number LIKE 'TEST-%'
AND NOT EXISTS (
    SELECT 1 FROM public.order_items oi 
    WHERE oi.order_id = o.id
)
RETURNING order_id, product_name;

-- Probar conversión
DO $$
DECLARE
    test_order_id UUID;
    result_invoice_id UUID;
BEGIN
    -- Obtener ID de orden de prueba
    SELECT id INTO test_order_id 
    FROM public.orders 
    WHERE order_number LIKE 'TEST-%' 
    LIMIT 1;
    
    IF test_order_id IS NOT NULL THEN
        RAISE NOTICE 'Probando conversión con orden: %', test_order_id;
        
        BEGIN
            SELECT public.convert_order_to_invoice(test_order_id, 'BASICA') INTO result_invoice_id;
            RAISE NOTICE 'SUCCESS: Conversión exitosa. Invoice ID: %', result_invoice_id;
        EXCEPTION
            WHEN OTHERS THEN
                RAISE NOTICE 'ERROR: Conversión falló: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'No se encontró orden de prueba para convertir';
    END IF;
END $$;

-- 5. Limpiar datos de prueba
DELETE FROM public.order_items 
WHERE order_id IN (
    SELECT id FROM public.orders WHERE order_number LIKE 'TEST-%'
);

DELETE FROM public.orders 
WHERE order_number LIKE 'TEST-%';

-- 6. Mostrar resumen final
SELECT '=== RESUMEN ===' as section;
SELECT 'Diagnóstico completado. Revisa los mensajes anteriores para identificar problemas.' as message;
