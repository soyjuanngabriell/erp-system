-- =====================================================
-- TEST RNC INTEGRATION AND ADD SAMPLE DATA
-- =====================================================
-- This script adds sample data to test the RNC integration

-- 1. Add some sample customers with RNC data
INSERT INTO public.customers (name, rnc_cedula, email, phone, address, is_active) VALUES
    ('Empresa ABC SRL', '123456789', 'contacto@empresaabc.com', '809-123-4567', 'Av. Principal #123, Santo Domingo', true),
    ('Comercial XYZ S.A.', '987654321', 'info@comercialxyz.com', '809-987-6543', 'Calle Secundaria #456, Santiago', true),
    ('Servicios Generales DEF', '456789123', 'servicios@def.com', '809-456-7890', 'Plaza Central #789, La Romana', true),
    ('Distribuidora GHI Ltda.', '789123456', 'ventas@ghi.com', '809-789-1234', 'Zona Industrial #321, San Pedro', true),
    ('Cliente Consumidor Final', NULL, 'cliente@email.com', '809-555-0123', 'Residencial Los Pinos #654', true)
ON CONFLICT (rnc_cedula) DO NOTHING;

-- 2. Add some sample products for testing
INSERT INTO public.products (name, sku, price, cost, stock, min_stock, is_active) VALUES
    ('Producto Test RNC 1', 'TEST-RNC-001', 150.00, 75.00, 50, 10, true),
    ('Producto Test RNC 2', 'TEST-RNC-002', 200.00, 100.00, 25, 5, true),
    ('Producto Test RNC 3', 'TEST-RNC-003', 300.00, 150.00, 15, 8, true),
    ('Producto Test RNC 4', 'TEST-RNC-004', 100.00, 50.00, 5, 10, true), -- Low stock for testing
    ('Producto Test RNC 5', 'TEST-RNC-005', 250.00, 125.00, 0, 5, true)  -- Critical stock for testing
ON CONFLICT (sku) DO NOTHING;

-- 3. Verify the data was inserted
SELECT 
    'Customers added:' as info,
    COUNT(*) as count
FROM public.customers 
WHERE name LIKE '%Test%' OR name LIKE '%ABC%' OR name LIKE '%XYZ%';

SELECT 
    'Products added:' as info,
    COUNT(*) as count
FROM public.products 
WHERE sku LIKE 'TEST-RNC-%';

-- 4. Show sample customers with RNC
SELECT 
    'Sample customers with RNC:' as info,
    name,
    rnc_cedula,
    email,
    phone
FROM public.customers 
WHERE rnc_cedula IS NOT NULL
ORDER BY name
LIMIT 5;

-- 5. Show products with low stock for testing
SELECT 
    'Products with low stock:' as info,
    name,
    sku,
    stock,
    min_stock,
    CASE 
        WHEN stock = 0 THEN 'CRÍTICO'
        WHEN stock <= min_stock THEN 'BAJO'
        ELSE 'OK'
    END as stock_status
FROM public.products 
WHERE stock <= min_stock
ORDER BY stock ASC;

-- 6. Test the low stock function
SELECT 'Testing low stock function...' as status;
SELECT * FROM public.get_low_stock_products();

-- 7. Show business config
SELECT 
    'Business configuration:' as info,
    business_name,
    rnc,
    low_stock_threshold
FROM public.business_config 
LIMIT 1;
