-- Script de diagnóstico para problemas de conversión a factura
-- Este script ayuda a identificar problemas específicos

-- 1. Verificar estructura de tablas
SELECT '=== ESTRUCTURA DE TABLAS ===' as section;

SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name IN ('orders', 'invoices', 'invoice_items', 'invoice_sequences')
ORDER BY table_name, ordinal_position;

-- 2. Verificar datos en invoice_sequences
SELECT '=== SECUENCIAS DE FACTURAS ===' as section;

SELECT 
    invoice_type,
    current_sequence,
    prefix,
    created_at,
    updated_at
FROM public.invoice_sequences
ORDER BY invoice_type;

-- 3. Verificar órdenes que podrían tener problemas
SELECT '=== ÓRDENES PARA CONVERSIÓN ===' as section;

SELECT 
    o.id,
    o.order_number,
    o.status,
    o.total,
    o.payment_amount,
    o.pending_amount,
    o.invoice_id,
    COUNT(oi.id) as item_count
FROM public.orders o
LEFT JOIN public.order_items oi ON o.id = oi.order_id
WHERE o.status = 'Completado' AND o.invoice_id IS NULL
GROUP BY o.id, o.order_number, o.status, o.total, o.payment_amount, o.pending_amount, o.invoice_id
ORDER BY o.created_at DESC;

-- 4. Verificar funciones disponibles
SELECT '=== FUNCIONES DISPONIBLES ===' as section;

SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('convert_order_to_invoice', 'get_next_invoice_number_by_type', 'generate_ncf')
ORDER BY routine_name;

-- 5. Probar función de obtener número de factura
SELECT '=== PRUEBA DE OBTENER NÚMERO DE FACTURA ===' as section;

DO $$
DECLARE
    test_number TEXT;
BEGIN
    BEGIN
        SELECT public.get_next_invoice_number_by_type('BASICA') INTO test_number;
        RAISE NOTICE 'Número de factura básica generado: %', test_number;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'ERROR al generar número de factura básica: %', SQLERRM;
    END;
END $$;

-- 6. Verificar si hay órdenes sin items
SELECT '=== ÓRDENES SIN ITEMS ===' as section;

SELECT 
    o.id,
    o.order_number,
    o.status,
    o.created_at
FROM public.orders o
LEFT JOIN public.order_items oi ON o.id = oi.order_id
WHERE oi.id IS NULL
ORDER BY o.created_at DESC;

-- 7. Verificar configuración de business_config
SELECT '=== CONFIGURACIÓN DE NEGOCIO ===' as section;

SELECT 
    company_name,
    fiscal_sequence,
    governmental_sequence,
    created_at,
    updated_at
FROM public.business_config
LIMIT 1;

-- 8. Mostrar mensaje final
SELECT '=== DIAGNÓSTICO COMPLETADO ===' as section;
SELECT 'Revisa los resultados anteriores para identificar problemas específicos.' as message;
