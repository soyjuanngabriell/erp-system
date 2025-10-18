-- Script para corregir la función convert_order_to_invoice
-- Este script corrige varios problemas en la función de conversión

-- Drop and recreate the function with better error handling
DROP FUNCTION IF EXISTS public.convert_order_to_invoice(UUID, invoice_type);

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
BEGIN
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
  
  -- Get next invoice number
  BEGIN
    SELECT public.get_next_invoice_number_by_type(p_invoice_type) INTO invoice_number;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Error getting invoice number: %', SQLERRM;
  END;
  
  -- Generate NCF for fiscal invoices (only if needed)
  ncf := NULL;
  IF p_invoice_type = 'VALOR_FISCAL' OR p_invoice_type = 'VALOR_GUBERNAMENTAL' THEN
    BEGIN
      -- Get the sequence number from the invoice number
      next_seq := CAST(SUBSTRING(invoice_number FROM '[0-9]+$') AS INTEGER);
      SELECT public.generate_ncf(p_invoice_type, next_seq) INTO ncf;
    EXCEPTION
      WHEN OTHERS THEN
        RAISE EXCEPTION 'Error generating NCF: %', SQLERRM;
    END;
  END IF;
  
  -- Create invoice
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
      order_record.customer_name,
      order_record.customer_rnc,
      order_record.customer_email,
      order_record.customer_phone,
      order_record.subtotal,
      order_record.tax,
      order_record.discount,
      order_record.total,
      order_record.payment_method,
      order_record.notes,
      order_record.created_by
    ) RETURNING id INTO invoice_id;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE EXCEPTION 'Error creating invoice: %', SQLERRM;
  END;
  
  -- Create invoice items from order items
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
      product_id,
      product_name,
      product_sku,
      quantity,
      unit_price,
      subtotal
    FROM public.order_items
    WHERE order_id = p_order_id;
  EXCEPTION
    WHEN OTHERS THEN
      -- If invoice items fail, clean up the invoice
      DELETE FROM public.invoices WHERE id = invoice_id;
      RAISE EXCEPTION 'Error creating invoice items: %', SQLERRM;
  END;
  
  -- Update order with invoice reference and status
  BEGIN
    UPDATE public.orders
    SET invoice_id = invoice_id,
        status = 'Facturada',
        updated_at = NOW()
    WHERE id = p_order_id;
  EXCEPTION
    WHEN OTHERS THEN
      -- If update fails, clean up invoice and items
      DELETE FROM public.invoice_items WHERE invoice_id = invoice_id;
      DELETE FROM public.invoices WHERE id = invoice_id;
      RAISE EXCEPTION 'Error updating order: %', SQLERRM;
  END;
  
  RETURN invoice_id;
END;
$$;

-- Test the function with a simple query
SELECT 'Function convert_order_to_invoice created successfully' as result;
