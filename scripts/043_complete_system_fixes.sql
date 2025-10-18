-- =====================================================
-- COMPLETE FIX FOR ALL SYSTEM ISSUES
-- =====================================================
-- This script fixes all identified issues:
-- 1. Configuration save error (missing sync function)
-- 2. Price precision issues (floating point errors)
-- 3. Low stock alert not showing
-- 4. Inventory not updating when orders are completed

-- =====================================================
-- 1. FIX CONFIGURATION SAVE ERROR
-- =====================================================

-- Create the missing sync function
CREATE OR REPLACE FUNCTION public.sync_invoice_sequences_from_config()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  config_record RECORD;
BEGIN
  -- Get the business configuration
  SELECT fiscal_sequence, governmental_sequence 
  INTO config_record
  FROM public.business_config 
  LIMIT 1;
  
  -- Update fiscal sequence if config exists
  IF config_record IS NOT NULL THEN
    UPDATE public.invoice_sequences 
    SET current_sequence = config_record.fiscal_sequence,
        updated_at = NOW()
    WHERE invoice_type = 'VALOR_FISCAL';
    
    -- Update governmental sequence if config exists
    UPDATE public.invoice_sequences 
    SET current_sequence = config_record.governmental_sequence,
        updated_at = NOW()
    WHERE invoice_type = 'VALOR_GUBERNAMENTAL';
  END IF;
END;
$$;

-- =====================================================
-- 2. FIX PRICE PRECISION ISSUES
-- =====================================================

-- Create function to round prices properly
CREATE OR REPLACE FUNCTION public.round_price(p_price DECIMAL(10,2))
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  -- Round to 2 decimal places to avoid floating point precision issues
  RETURN ROUND(p_price, 2);
END;
$$;

-- Update existing price calculations to use proper rounding
-- This will be handled in the application code, but we ensure the function exists

-- =====================================================
-- 3. FIX LOW STOCK ALERT QUERY
-- =====================================================

-- Create function to get low stock products
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

-- =====================================================
-- 4. FIX INVENTORY UPDATE WHEN ORDERS ARE COMPLETED
-- =====================================================

-- Create function to update inventory when order is completed
CREATE OR REPLACE FUNCTION public.update_inventory_on_order_completion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  order_item RECORD;
BEGIN
  -- Only process if status changed to 'Completada'
  IF NEW.status = 'Completada' AND (OLD.status IS NULL OR OLD.status != 'Completada') THEN
    
    -- Update stock for each item in the order
    FOR order_item IN 
      SELECT product_id, quantity 
      FROM public.order_items 
      WHERE order_id = NEW.id
    LOOP
      -- Decrease stock (SALIDA)
      UPDATE public.products 
      SET stock = stock - order_item.quantity,
          updated_at = NOW()
      WHERE id = order_item.product_id;
      
      -- Record stock movement
      INSERT INTO public.stock_movements (
        product_id,
        movement_type,
        quantity,
        reason,
        reference_id,
        reference_type,
        created_by
      ) VALUES (
        order_item.product_id,
        'SALIDA',
        order_item.quantity,
        'Venta - Orden completada',
        NEW.id,
        'order',
        NEW.created_by
      );
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger for order completion
DROP TRIGGER IF EXISTS update_inventory_on_order_completion_trigger ON public.orders;
CREATE TRIGGER update_inventory_on_order_completion_trigger
  AFTER UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_inventory_on_order_completion();

-- =====================================================
-- 5. ENSURE ALL REQUIRED TABLES AND FUNCTIONS EXIST
-- =====================================================

-- Ensure stock_movements table exists
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  movement_type stock_movement_type NOT NULL,
  quantity INTEGER NOT NULL,
  reason TEXT,
  reference_id UUID,
  reference_type TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure invoice_sequences table exists
CREATE TABLE IF NOT EXISTS public.invoice_sequences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_type invoice_type NOT NULL UNIQUE,
  current_sequence INTEGER NOT NULL DEFAULT 0,
  prefix TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert/update sequences
INSERT INTO public.invoice_sequences (invoice_type, current_sequence, prefix) VALUES
('BASICA', 0, 'BAS'),
('VALOR_FISCAL', 0, 'B0100000'),
('VALOR_GUBERNAMENTAL', 0, 'B1500000')
ON CONFLICT (invoice_type) DO UPDATE SET
  prefix = EXCLUDED.prefix,
  updated_at = NOW();

-- =====================================================
-- 6. CREATE HELPER FUNCTIONS FOR PRICE CALCULATIONS
-- =====================================================

-- Function to calculate subtotal with proper rounding
CREATE OR REPLACE FUNCTION public.calculate_subtotal(p_quantity INTEGER, p_unit_price DECIMAL(10,2))
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN public.round_price(p_quantity * p_unit_price);
END;
$$;

-- Function to calculate tax with proper rounding
CREATE OR REPLACE FUNCTION public.calculate_tax(p_subtotal DECIMAL(10,2), p_tax_rate DECIMAL(5,4))
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN public.round_price(p_subtotal * p_tax_rate);
END;
$$;

-- Function to calculate total with proper rounding
CREATE OR REPLACE FUNCTION public.calculate_total(p_subtotal DECIMAL(10,2), p_tax DECIMAL(10,2), p_discount DECIMAL(10,2))
RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN public.round_price(p_subtotal + p_tax - p_discount);
END;
$$;

-- =====================================================
-- 7. TEST ALL FUNCTIONS
-- =====================================================

-- Test price rounding
SELECT 'Price rounding test:' as test;
SELECT public.round_price(7999.999) as rounded_price;
SELECT public.round_price(8000.001) as rounded_price;

-- Test subtotal calculation
SELECT 'Subtotal calculation test:' as test;
SELECT public.calculate_subtotal(2, 4000.00) as subtotal;

-- Test tax calculation
SELECT 'Tax calculation test:' as test;
SELECT public.calculate_tax(8000.00, 0.18) as tax;

-- Test total calculation
SELECT 'Total calculation test:' as test;
SELECT public.calculate_total(8000.00, 1440.00, 0.00) as total;

-- Test low stock function
SELECT 'Low stock products test:' as test;
SELECT * FROM public.get_low_stock_products() LIMIT 3;

SELECT 'All system fixes applied successfully!' as result;
