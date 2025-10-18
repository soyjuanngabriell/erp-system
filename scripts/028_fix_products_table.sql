-- =====================================================
-- DIAGNÓSTICO Y CORRECCIÓN DE TABLA PRODUCTS
-- =====================================================
-- Este script diagnostica problemas con la tabla products
-- y corrige cualquier inconsistencia

-- =====================================================
-- 1. VERIFICAR ESTRUCTURA ACTUAL DE LA TABLA PRODUCTS
-- =====================================================

SELECT '=== ESTRUCTURA ACTUAL DE PRODUCTS ===' as section;

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    character_maximum_length
FROM information_schema.columns 
WHERE table_name = 'products' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- =====================================================
-- 2. VERIFICAR SI EXISTE EL CAMPO CATEGORY
-- =====================================================

SELECT '=== VERIFICACIÓN DE CAMPO CATEGORY ===' as section;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' 
        AND column_name = 'category'
        AND table_schema = 'public'
    ) THEN
        RAISE NOTICE 'Campo category EXISTE en la tabla products';
    ELSE
        RAISE NOTICE 'Campo category NO EXISTE en la tabla products';
    END IF;
END $$;

-- =====================================================
-- 3. AGREGAR CAMPO CATEGORY SI NO EXISTE
-- =====================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'products' 
        AND column_name = 'category'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.products ADD COLUMN category TEXT;
        RAISE NOTICE 'Campo category agregado a la tabla products';
    ELSE
        RAISE NOTICE 'Campo category ya existe, no se necesita agregar';
    END IF;
END $$;

-- =====================================================
-- 4. VERIFICAR DATOS EXISTENTES
-- =====================================================

SELECT '=== DATOS EXISTENTES EN PRODUCTS ===' as section;

SELECT 
    COUNT(*) as total_products,
    COUNT(CASE WHEN category IS NOT NULL THEN 1 END) as products_with_category,
    COUNT(CASE WHEN category IS NULL THEN 1 END) as products_without_category
FROM public.products;

-- Mostrar algunos productos de ejemplo
SELECT 
    name,
    sku,
    category,
    price,
    stock,
    is_active
FROM public.products
LIMIT 5;

-- =====================================================
-- 5. VERIFICAR CONSTRAINTS Y ÍNDICES
-- =====================================================

SELECT '=== CONSTRAINTS E ÍNDICES ===' as section;

-- Mostrar constraints
SELECT 
    tc.constraint_name,
    tc.constraint_type,
    kcu.column_name
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'products'
AND tc.table_schema = 'public';

-- Mostrar índices
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'products'
AND schemaname = 'public';

-- =====================================================
-- 6. PROBAR INSERCIÓN DE PRODUCTO DE PRUEBA
-- =====================================================

SELECT '=== PRUEBA DE INSERCIÓN ===' as section;

-- Insertar producto de prueba
INSERT INTO public.products (
    name,
    sku,
    description,
    cost,
    price,
    stock,
    min_stock,
    category,
    is_active
) VALUES (
    'Producto de Prueba',
    'TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
    'Producto creado para probar la inserción',
    100.00,
    150.00,
    50,
    5,
    'Prueba',
    true
) ON CONFLICT (sku) DO NOTHING
RETURNING id, name, sku, category;

-- =====================================================
-- 7. LIMPIAR DATOS DE PRUEBA
-- =====================================================

-- Eliminar producto de prueba
DELETE FROM public.products 
WHERE sku LIKE 'TEST-%';

-- =====================================================
-- 8. RESUMEN FINAL
-- =====================================================

SELECT '=== RESUMEN FINAL ===' as section;

SELECT 
    'Tabla products' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'products' AND table_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Campo category' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'products' AND column_name = 'category' AND table_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado
UNION ALL
SELECT 
    'Constraint UNIQUE en sku' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'products' AND constraint_type = 'UNIQUE' AND table_schema = 'public') 
         THEN 'EXISTE' 
         ELSE 'NO EXISTE' 
    END as estado;

-- Mostrar estructura final
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'products' 
AND table_schema = 'public'
ORDER BY ordinal_position;

SELECT 'Diagnóstico y corrección de tabla products completado.' as result;
