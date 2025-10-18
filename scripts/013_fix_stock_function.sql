-- Verify and recreate the update_product_stock function
-- This ensures the function exists and works correctly

-- Drop the function if it exists
DROP FUNCTION IF EXISTS public.update_product_stock(UUID, INTEGER, TEXT, TEXT, UUID, UUID);

-- Recreate the function with proper error handling
CREATE OR REPLACE FUNCTION public.update_product_stock(
  p_product_id UUID,
  p_quantity INTEGER,
  p_type TEXT,
  p_reason TEXT DEFAULT NULL,
  p_reference_id UUID DEFAULT NULL,
  p_user_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
  current_stock INTEGER;
  new_stock INTEGER;
  result JSON;
BEGIN
  -- Get current stock
  SELECT stock INTO current_stock
  FROM public.products
  WHERE id = p_product_id;
  
  -- Check if product exists
  IF current_stock IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Product not found');
  END IF;
  
  -- Calculate new stock
  new_stock := current_stock + p_quantity;
  
  -- Check if stock would go negative
  IF new_stock < 0 THEN
    RETURN json_build_object('success', false, 'error', 'Insufficient stock', 'current_stock', current_stock, 'requested', ABS(p_quantity));
  END IF;
  
  -- Update product stock
  UPDATE public.products
  SET stock = new_stock
  WHERE id = p_product_id;
  
  -- Record stock movement
  INSERT INTO public.stock_movements (
    product_id,
    quantity,
    type,
    reason,
    reference_id,
    created_by
  ) VALUES (
    p_product_id,
    p_quantity,
    p_type,
    p_reason,
    p_reference_id,
    p_user_id
  );
  
  RETURN json_build_object('success', true, 'old_stock', current_stock, 'new_stock', new_stock);
EXCEPTION
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$;
