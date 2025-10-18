-- Function to auto-create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'Vendedor')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Trigger to create profile on signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- Add updated_at triggers to relevant tables
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_business_config_updated_at
  BEFORE UPDATE ON public.business_config
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_customers_updated_at
  BEFORE UPDATE ON public.customers
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- Function to generate next invoice number atomically
CREATE OR REPLACE FUNCTION public.get_next_invoice_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  next_num INTEGER;
  prefix TEXT;
  invoice_num TEXT;
BEGIN
  -- Lock the row and increment
  UPDATE public.invoice_counter
  SET current_number = current_number + 1
  WHERE id = 1
  RETURNING current_number, invoice_counter.prefix INTO next_num, prefix;
  
  -- Format the invoice number with leading zeros
  invoice_num := prefix || '-' || LPAD(next_num::TEXT, 8, '0');
  
  RETURN invoice_num;
END;
$$;

-- Function to update product stock
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
END;
$$;
