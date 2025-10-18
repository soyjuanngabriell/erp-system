-- =====================================================
-- CORREGIR VALORES DE ENUMS PARA COINCIDIR CON FRONTEND
-- =====================================================
-- Este script corrige los valores de los enums para que coincidan
-- con lo que está usando el frontend

-- =====================================================
-- 1. VERIFICAR VALORES ACTUALES DE LOS ENUMS
-- =====================================================

SELECT '=== VALORES ACTUALES DE ENUMS ===' as section;

-- order_status
SELECT 'order_status:' as enum_name, enumlabel as value
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')
ORDER BY enumsortorder;

-- payment_status
SELECT 'payment_status:' as enum_name, enumlabel as value
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')
ORDER BY enumsortorder;

-- =====================================================
-- 2. AGREGAR VALORES FALTANTES A LOS ENUMS
-- =====================================================

-- Agregar valores faltantes a order_status si no existen
DO $$
BEGIN
    -- Verificar y agregar valores faltantes
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Asignada' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')) THEN
        ALTER TYPE order_status ADD VALUE 'Asignada';
        RAISE NOTICE 'Agregado valor Asignada a order_status';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Facturada' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')) THEN
        ALTER TYPE order_status ADD VALUE 'Facturada';
        RAISE NOTICE 'Agregado valor Facturada a order_status';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Cancelada' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')) THEN
        ALTER TYPE order_status ADD VALUE 'Cancelada';
        RAISE NOTICE 'Agregado valor Cancelada a order_status';
    END IF;
END $$;

-- Agregar valores faltantes a payment_status si no existen
DO $$
BEGIN
    -- Verificar y agregar valores faltantes
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Parcial' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')) THEN
        ALTER TYPE payment_status ADD VALUE 'Parcial';
        RAISE NOTICE 'Agregado valor Parcial a payment_status';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Completo' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')) THEN
        ALTER TYPE payment_status ADD VALUE 'Completo';
        RAISE NOTICE 'Agregado valor Completo a payment_status';
    END IF;
END $$;

-- =====================================================
-- 3. VERIFICAR VALORES DESPUÉS DE LA CORRECCIÓN
-- =====================================================

SELECT '=== VALORES DESPUÉS DE LA CORRECCIÓN ===' as section;

-- order_status
SELECT 'order_status:' as enum_name, enumlabel as value
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')
ORDER BY enumsortorder;

-- payment_status
SELECT 'payment_status:' as enum_name, enumlabel as value
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')
ORDER BY enumsortorder;

-- =====================================================
-- 4. PROBAR INSERCIÓN CON VALORES CORREGIDOS
-- =====================================================

SELECT '=== PRUEBA DE INSERCIÓN CON VALORES CORREGIDOS ===' as section;

-- Crear datos de prueba
INSERT INTO public.customers (name, rnc_cedula) VALUES
('Cliente Test', '999999999')
ON CONFLICT (rnc_cedula) DO NOTHING;

INSERT INTO public.products (name, sku, price, stock) VALUES
('Producto Test', 'TEST-001', 100.00, 50)
ON CONFLICT (sku) DO NOTHING;

-- Probar inserción de orden con valores corregidos
DO $$
DECLARE
    test_customer_id UUID;
    test_user_id UUID;
    test_order_id UUID;
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '999999999' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    -- Probar inserción
    INSERT INTO public.orders (
        order_number,
        customer_id,
        customer_name,
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
        'TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
        test_customer_id,
        'Cliente Test',
        'Pendiente',
        'BASICA',
        100.00,
        0.00,
        100.00,
        0.00,
        100.00,
        'Pendiente',
        test_user_id
    ) RETURNING id INTO test_order_id;

    RAISE NOTICE 'SUCCESS: Orden creada con ID: %', test_order_id;

    -- Limpiar
    DELETE FROM public.orders WHERE id = test_order_id;

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ERROR: %', SQLERRM;
END $$;

-- =====================================================
-- 5. LIMPIAR DATOS DE PRUEBA
-- =====================================================

DELETE FROM public.products WHERE sku = 'TEST-001';
DELETE FROM public.customers WHERE rnc_cedula = '999999999';

-- =====================================================
-- 6. RESUMEN FINAL
-- =====================================================

SELECT '=== RESUMEN FINAL ===' as section;

SELECT 
    'Enums corregidos' as acción,
    'Valores agregados para coincidir con frontend' as resultado;

SELECT 'Corrección de enums completada exitosamente.' as result;
