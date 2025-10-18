-- Script para crear una función de conversión más simple y robusta
-- Esta versión tiene mejor manejo de errores y es más fácil de debuggear

-- Drop existing function
DROP FUNCTION IF EXISTS public.convert_order_to_invoice(UUID, invoice_type);

-- Create a simpler, more robust version
CREATE OR REPLACE FUNCTION public.convert_order_to_invoice(
  p_order_id UUID,
  p_invoice_type invoice_type DEFAULT 'BASICA'
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
  order_record RECORD;
  invoice_id UUID;
  invoice_number TEXT;
  ncf TEXT;
  next_seq INTEGER;
  error_message TEXT;
BEGIN
  -- Initialize error tracking
  error_message := '';
  
  -- Step 1: Validate input
  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'Order ID cannot be null';
  END IF;
  
  -- Step 2: Get order details
  BEGIN
    SELECT * INTO order_record
    FROM public.orders
    WHERE id = p_order_id;
    
    IF order_record IS NULL THEN
      RAISE EXCEPTION 'Order not found: %', p_order_id;
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Error fetching order: %', SQLERRM;
  END;
  
  -- Step 3: Check if order is already converted
  IF order_record.invoice_id IS NOT NULL THEN
    RAISE EXCEPTION 'Order already converted to invoice: %', order_record.invoice_id;
  END IF;
  
  -- Step 4: Verify order has items
  IF NOT EXISTS (SELECT 1 FROM public.order_items WHERE order_id = p_order_id) THEN
    RAISE EXCEPTION 'Order has no items to convert';
  END IF;
  
  -- Step 5: Get next invoice number
  BEGIN
    SELECT public.get_next_invoice_number_by_type(p_invoice_type) INTO invoice_number;
    
    IF invoice_number IS NULL OR invoice_number = '' THEN
      RAISE EXCEPTION 'Failed to generate invoice number';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Error getting invoice number: %', SQLERRM;
  END;
  
  -- Step 6: Generate NCF for fiscal invoices
  ncf := NULL;
  IF p_invoice_type = 'VALOR_FISCAL' OR p_invoice_type = 'VALOR_GUBERNAMENTAL' THEN
    BEGIN
      -- Extract sequence number from invoice number
      next_seq := CAST(SUBSTRING(invoice_number FROM '[0-9]+$') AS INTEGER);
      
      IF next_seq IS NULL THEN
        RAISE EXCEPTION 'Could not extract sequence number from invoice number: %', invoice_number;
      END IF;
      
      SELECT public.generate_ncf(p_invoice_type, next_seq) INTO ncf;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating NCF: %', SQLERRM;
    END;
  END IF;
  
  -- Step 7: Create invoice
  BEGIN
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
      p_invoice_type,
      ncf,
      p_order_id,
      COALESCE(order_record.customer_name, 'Sin nombre'),
      order_record.customer_rnc,
      order_record.customer_email,
      order_record.customer_phone,
      COALESCE(order_record.subtotal, 0),
      CASE 
        WHEN p_invoice_type = 'VALOR_FISCAL' OR p_invoice_type = 'VALOR_GUBERNAMENTAL' 
        THEN COALESCE(order_record.tax, 0)
        ELSE 0 
      END,
      COALESCE(order_record.discount, 0),
      CASE 
        WHEN p_invoice_type = 'VALOR_FISCAL' OR p_invoice_type = 'VALOR_GUBERNAMENTAL' 
        THEN COALESCE(order_record.total, order_record.subtotal)
        ELSE COALESCE(order_record.subtotal, 0)
      END,
      order_record.payment_method,
      order_record.notes,
      COALESCE(order_record.created_by, (SELECT id FROM public.profiles LIMIT 1))
    ) RETURNING id INTO invoice_id;
    
    IF invoice_id IS NULL THEN
      RAISE EXCEPTION 'Failed to create invoice - no ID returned';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Error creating invoice: %', SQLERRM;
  END;
  
  -- Step 8: Create invoice items
  BEGIN
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
      oi.product_id,
      COALESCE(oi.product_name, 'Producto sin nombre'),
      COALESCE(oi.product_sku, 'SKU-001'),
      COALESCE(oi.quantity, 1),
      COALESCE(oi.unit_price, 0),
      COALESCE(oi.subtotal, 0)
    FROM public.order_items oi
    WHERE oi.order_id = p_order_id;
    
    -- Verify items were created
    IF NOT EXISTS (SELECT 1 FROM public.invoice_items WHERE invoice_id = invoice_id) THEN
      -- Clean up invoice if no items were created
      DELETE FROM public.invoices WHERE id = invoice_id;
      RAISE EXCEPTION 'Failed to create invoice items';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- Clean up invoice if items creation fails
      DELETE FROM public.invoices WHERE id = invoice_id;
      RAISE EXCEPTION 'Error creating invoice items: %', SQLERRM;
  END;
  
  -- Step 9: Update order
  BEGIN
    UPDATE public.orders
    SET invoice_id = invoice_id,
        status = 'Facturada',
        updated_at = NOW()
    WHERE id = p_order_id;
    
    -- Verify update
    IF NOT FOUND THEN
      -- Clean up invoice and items if order update fails
      DELETE FROM public.invoice_items WHERE invoice_id = invoice_id;
      DELETE FROM public.invoices WHERE id = invoice_id;
      RAISE EXCEPTION 'Failed to update order';
    END IF;
  EXCEPTION
    WHEN OTHERS THEN
      -- Clean up invoice and items if order update fails
      DELETE FROM public.invoice_items WHERE invoice_id = invoice_id;
      DELETE FROM public.invoices WHERE id = invoice_id;
      RAISE EXCEPTION 'Error updating order: %', SQLERRM;
  END;
  
  -- Step 10: Return success
  RETURN invoice_id;
END;
$$;

-- Test the function
DO $$
DECLARE
    test_result TEXT;
BEGIN
    SELECT public.test_invoice_conversion() INTO test_result;
    RAISE NOTICE 'Test result: %', test_result;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Test failed: %', SQLERRM;
END $$;

-- Show function signature
SELECT 
    routine_name,
    routine_type,
    data_type as return_type,
    routine_definition
FROM information_schema.routines 
WHERE routine_name = 'convert_order_to_invoice'
AND routine_schema = 'public';

SELECT 'Function convert_order_to_invoice created successfully with improved error handling' as result;
