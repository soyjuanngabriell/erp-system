-- =====================================================
-- FIX LOW STOCK CALCULATION AND ADD TEST DATA
-- =====================================================
-- This script fixes the low stock calculation and adds test data

-- 1. Ensure products table has proper structure
ALTER TABLE public.products 
ALTER COLUMN min_stock SET DEFAULT 10;

-- 2. Update existing products to have proper min_stock values if they are 0
UPDATE public.products 
SET min_stock = 10 
WHERE min_stock = 0 OR min_stock IS NULL;

-- 3. Add some test products with different stock levels for testing
INSERT INTO public.products (name, sku, price, cost, stock, min_stock, is_active) VALUES
    ('Producto Test Stock Bajo', 'TEST-LOW-001', 100.00, 50.00, 5, 10, true),
    ('Producto Test Stock Normal', 'TEST-NORM-001', 150.00, 75.00, 25, 10, true),
    ('Producto Test Stock Crítico', 'TEST-CRIT-001', 200.00, 100.00, 2, 15, true),
    ('Producto Test Stock Mínimo', 'TEST-MIN-001', 80.00, 40.00, 10, 10, true),
    ('Producto Test Inactivo', 'TEST-INACT-001', 120.00, 60.00, 3, 10, false)
ON CONFLICT (sku) DO NOTHING;

-- 4. Create a function to get low stock products (for future use)
CREATE OR REPLACE FUNCTION public.get_low_stock_products()
RETURNS TABLE (
  id UUID,
  name TEXT,
  sku TEXT,
  stock INTEGER,
  min_stock INTEGER,
  price DECIMAL(10,2),
  is_active BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.id,
    p.name,
    p.sku,
    p.stock,
    p.min_stock,
    p.price,
    p.is_active
  FROM public.products p
  WHERE p.stock <= p.min_stock 
    AND p.is_active = true
  ORDER BY p.stock ASC;
END;
$$;

-- 5. Test the function
SELECT 'Testing low stock function...' as status;
SELECT * FROM public.get_low_stock_products();

-- 6. Show current products with their stock levels
SELECT 
    'Current products and stock levels:' as info,
    name,
    sku,
    stock,
    min_stock,
    CASE 
        WHEN stock <= min_stock THEN 'LOW STOCK'
        ELSE 'OK'
    END as stock_status,
    is_active
FROM public.products 
ORDER BY stock ASC;

-- 7. Verify business config has low_stock_threshold
SELECT 
    'Business config verification:' as info,
    business_name,
    low_stock_threshold
FROM public.business_config 
LIMIT 1;
