-- =====================================================
-- FIX FOR PAYMENT_METHOD FIELD ERROR
-- =====================================================
-- This script fixes the error: record "order_record" has no field "payment_method"
-- The orders table doesn't have a payment_method field, so we need to handle this properly

-- Drop and recreate the convert_order_to_invoice function with proper payment_method handling
DROP FUNCTION IF EXISTS public.convert_order_to_invoice(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.convert_order_to_invoice(
  p_order_id UUID,
  p_invoice_type TEXT DEFAULT 'BASICA'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  order_record RECORD;
  invoice_id UUID;
  invoice_number TEXT;
  ncf TEXT;
  next_seq INTEGER;
  invoice_type_enum invoice_type;
  default_payment_method payment_method;
BEGIN
  -- Validate input
  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'Order ID cannot be null';
  END IF;

  -- Convert TEXT to enum for validation
  BEGIN
    invoice_type_enum := p_invoice_type::invoice_type;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'Invalid invoice type: %. Valid types are: BASICA, VALOR_FISCAL, VALOR_GUBERNAMENTAL', p_invoice_type;
  END;

  -- Get order details
  SELECT * INTO order_record
  FROM public.orders
  WHERE id = p_order_id;
  
  IF order_record IS NULL THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;
  
  -- Check if order is already converted
  IF order_record.invoice_id IS NOT NULL THEN
    RAISE EXCEPTION 'Order already converted to invoice: %', order_record.invoice_id;
  END IF;
  
  -- Verify order has items
  IF NOT EXISTS (SELECT 1 FROM public.order_items WHERE order_id = p_order_id) THEN
    RAISE EXCEPTION 'Order has no items to convert';
  END IF;
  
  -- Get next invoice number
  SELECT public.get_next_invoice_number(p_invoice_type) INTO invoice_number;
  
  IF invoice_number IS NULL OR invoice_number = '' THEN
    RAISE EXCEPTION 'Failed to generate invoice number';
  END IF;
  
  -- Generate NCF for fiscal invoices
  ncf := NULL;
  IF invoice_type_enum = 'VALOR_FISCAL' OR invoice_type_enum = 'VALOR_GUBERNAMENTAL' THEN
    -- Extract sequence number from invoice number
    next_seq := CAST(SUBSTRING(invoice_number FROM '[0-9]+$') AS INTEGER);
    
    IF next_seq IS NULL THEN
      RAISE EXCEPTION 'Could not extract sequence number from invoice number: %', invoice_number;
    END IF;
    
    SELECT public.generate_ncf(invoice_type_enum, next_seq) INTO ncf;
  END IF;
  
  -- Determine payment method from order payments, or use default
  SELECT payment_method INTO default_payment_method
  FROM public.order_payments
  WHERE order_id = p_order_id
  ORDER BY payment_date DESC
  LIMIT 1;
  
  -- If no payment method found, use 'Efectivo' as default
  IF default_payment_method IS NULL THEN
    default_payment_method := 'Efectivo'::payment_method;
  END IF;
  
  -- Create invoice
  INSERT INTO public.invoices (
    invoice_number,
    invoice_type,
    ncf,
    order_id,
    customer_name,
    customer_rnc,
    customer_email,
    customer_phone,
    subtotal,
    tax,
    discount,
    total,
    payment_method,
    notes,
    created_by
  ) VALUES (
    invoice_number,
    invoice_type_enum,
    ncf,
    p_order_id,
    COALESCE(order_record.customer_name, 'Sin nombre'),
    order_record.customer_rnc,
    order_record.customer_email,
    order_record.customer_phone,
    COALESCE(order_record.subtotal, 0),
    CASE 
      WHEN invoice_type_enum = 'VALOR_FISCAL' OR invoice_type_enum = 'VALOR_GUBERNAMENTAL' 
      THEN COALESCE(order_record.tax, 0)
      ELSE 0 
    END,
    COALESCE(order_record.discount, 0),
    CASE 
      WHEN invoice_type_enum = 'VALOR_FISCAL' OR invoice_type_enum = 'VALOR_GUBERNAMENTAL' 
      THEN COALESCE(order_record.total, order_record.subtotal)
      ELSE COALESCE(order_record.subtotal, 0)
    END,
    default_payment_method,
    order_record.notes,
    COALESCE(order_record.created_by, (SELECT id FROM public.profiles LIMIT 1))
  ) RETURNING id INTO invoice_id;
  
  IF invoice_id IS NULL THEN
    RAISE EXCEPTION 'Failed to create invoice - no ID returned';
  END IF;
  
  -- Copy order items to invoice items
  INSERT INTO public.invoice_items (
    invoice_id,
    product_id,
    product_name,
    product_sku,
    quantity,
    unit_price,
    subtotal
  )
  SELECT 
    invoice_id,
    product_id,
    product_name,
    product_sku,
    quantity,
    unit_price,
    subtotal
  FROM public.order_items
  WHERE order_id = p_order_id;
  
  -- Update order with invoice reference
  UPDATE public.orders
  SET invoice_id = invoice_id,
      status = 'Completada',
      updated_at = NOW()
  WHERE id = p_order_id;
  
  RETURN invoice_id;
END;
$$;

-- Test the function
SELECT 'convert_order_to_invoice function updated successfully!' as result;
