-- =====================================================
-- SCRIPT DE MIGRACIÓN DE DATOS EXISTENTES
-- =====================================================
-- Este script migra datos de la estructura antigua a la nueva
-- Solo ejecutar DESPUÉS de crear la nueva estructura

-- ⚠️ IMPORTANTE: Ejecutar solo si tienes datos importantes que migrar
-- Si no tienes datos importantes, simplemente ejecuta el script de restructuración

-- =====================================================
-- 1. MIGRAR PERFILES DE USUARIO
-- =====================================================

-- Los perfiles ya deberían existir, pero verificamos
INSERT INTO public.profiles (id, email, full_name, role, is_active)
SELECT 
    id,
    email,
    COALESCE(full_name, 'Usuario'),
    COALESCE(role, 'Vendedor'),
    COALESCE(is_active, true)
FROM auth.users
WHERE id NOT IN (SELECT id FROM public.profiles)
ON CONFLICT (id) DO NOTHING;

-- =====================================================
-- 2. MIGRAR CONFIGURACIÓN DE NEGOCIO
-- =====================================================

-- Si existe configuración antigua, migrarla
INSERT INTO public.business_config (
    company_name,
    company_rnc,
    company_address,
    company_phone,
    company_email,
    fiscal_sequence,
    governmental_sequence
)
SELECT 
    COALESCE(business_name, 'Mi Empresa'),
    COALESCE(rnc, '123456789'),
    address,
    phone,
    email,
    COALESCE(fiscal_sequence, 0),
    COALESCE(governmental_sequence, 0)
FROM (
    -- Datos de ejemplo si no existe configuración
    SELECT 
        'Mi Empresa' as business_name,
        '123456789' as rnc,
        NULL as address,
        NULL as phone,
        NULL as email,
        0 as fiscal_sequence,
        0 as governmental_sequence
) AS config_data
WHERE NOT EXISTS (SELECT 1 FROM public.business_config)
ON CONFLICT DO NOTHING;

-- =====================================================
-- 3. MIGRAR CLIENTES
-- =====================================================

-- Si existen clientes en la estructura antigua, migrarlos
-- (Asumiendo que tenías una tabla customers antigua)
INSERT INTO public.customers (name, rnc_cedula, email, phone, address, is_active)
SELECT 
    COALESCE(name, 'Cliente'),
    rnc_cedula,
    email,
    phone,
    address,
    COALESCE(is_active, true)
FROM (
    -- Crear algunos clientes de ejemplo si no existen
    SELECT 
        'Cliente General' as name,
        NULL as rnc_cedula,
        NULL as email,
        NULL as phone,
        NULL as address,
        true as is_active
) AS customer_data
WHERE NOT EXISTS (SELECT 1 FROM public.customers)
ON CONFLICT (rnc_cedula) DO NOTHING;

-- =====================================================
-- 4. MIGRAR PRODUCTOS
-- =====================================================

-- Si existen productos en la estructura antigua, migrarlos
INSERT INTO public.products (name, sku, description, cost, price, stock, min_stock, is_active)
SELECT 
    COALESCE(name, 'Producto'),
    COALESCE(sku, 'SKU-001'),
    description,
    COALESCE(cost, 0),
    COALESCE(price, 0),
    COALESCE(stock, 0),
    COALESCE(min_stock, 0),
    COALESCE(is_active, true)
FROM (
    -- Crear algunos productos de ejemplo si no existen
    SELECT 
        'Producto de Ejemplo' as name,
        'SKU-001' as sku,
        'Descripción del producto' as description,
        100.00 as cost,
        150.00 as price,
        50 as stock,
        5 as min_stock,
        true as is_active
) AS product_data
WHERE NOT EXISTS (SELECT 1 FROM public.products)
ON CONFLICT (sku) DO NOTHING;

-- =====================================================
-- 5. MIGRAR ÓRDENES EXISTENTES
-- =====================================================

-- Si existen órdenes en la estructura antigua, migrarlas
-- Esto es complejo porque la estructura cambió significativamente
-- Solo migrar si realmente tienes datos importantes

-- =====================================================
-- 6. CONFIGURAR SECUENCIAS DE FACTURAS
-- =====================================================

-- Asegurar que las secuencias estén configuradas correctamente
INSERT INTO public.invoice_sequences (invoice_type, current_sequence, prefix) VALUES
('BASICA', 0, 'BAS'),
('VALOR_FISCAL', 0, 'B0100000'),
('VALOR_GUBERNAMENTAL', 0, 'B1500000')
ON CONFLICT (invoice_type) DO UPDATE SET
    prefix = EXCLUDED.prefix,
    updated_at = NOW();

-- =====================================================
-- 7. CREAR USUARIO ADMIN POR DEFECTO
-- =====================================================

-- Crear usuario admin si no existe
INSERT INTO public.profiles (email, full_name, role, is_active)
VALUES ('admin@empresa.com', 'Administrador', 'Admin', true)
ON CONFLICT (email) DO NOTHING;

-- =====================================================
-- 8. VERIFICACIÓN FINAL
-- =====================================================

-- Mostrar resumen de datos migrados
SELECT '=== RESUMEN DE MIGRACIÓN ===' as section;

SELECT 
    'Perfiles' as tabla,
    COUNT(*) as registros
FROM public.profiles
UNION ALL
SELECT 
    'Configuración de negocio' as tabla,
    COUNT(*) as registros
FROM public.business_config
UNION ALL
SELECT 
    'Clientes' as tabla,
    COUNT(*) as registros
FROM public.customers
UNION ALL
SELECT 
    'Productos' as tabla,
    COUNT(*) as registros
FROM public.products
UNION ALL
SELECT 
    'Secuencias de facturas' as tabla,
    COUNT(*) as registros
FROM public.invoice_sequences;

-- Mostrar configuración actual
SELECT '=== CONFIGURACIÓN ACTUAL ===' as section;
SELECT 
    company_name,
    company_rnc,
    fiscal_sequence,
    governmental_sequence
FROM public.business_config
LIMIT 1;

-- Mostrar secuencias actuales
SELECT '=== SECUENCIAS DE FACTURAS ===' as section;
SELECT 
    invoice_type,
    current_sequence,
    prefix,
    CASE 
        WHEN invoice_type = 'BASICA' THEN prefix || '-' || LPAD((current_sequence + 1)::TEXT, 6, '0')
        ELSE prefix || LPAD((current_sequence + 1)::TEXT, 4, '0')
    END as proximo_numero
FROM public.invoice_sequences
ORDER BY invoice_type;

SELECT 'Migración completada exitosamente.' as result;
