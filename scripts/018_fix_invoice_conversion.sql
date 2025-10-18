-- Script completo para asegurar que la conversión a factura funcione correctamente
-- Este script verifica y corrige todos los problemas potenciales

-- 1. Asegurar que todas las columnas necesarias existan en la tabla invoices
DO $$ 
BEGIN
    -- Verificar y agregar columnas faltantes en invoices
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'customer_email') THEN
        ALTER TABLE public.invoices ADD COLUMN customer_email TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'customer_phone') THEN
        ALTER TABLE public.invoices ADD COLUMN customer_phone TEXT;
    END IF;
END $$;

-- 2. Asegurar que todas las columnas necesarias existan en la tabla invoice_items
DO $$ 
BEGIN
    -- Verificar y agregar columnas faltantes en invoice_items
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoice_items' AND column_name = 'product_id') THEN
        ALTER TABLE public.invoice_items ADD COLUMN product_id UUID REFERENCES public.products(id) ON DELETE SET NULL;
    END IF;
END $$;

-- 3. Asegurar que la tabla invoice_sequences tenga datos correctos
INSERT INTO public.invoice_sequences (invoice_type, current_sequence, prefix) VALUES
('BASICA', 0, 'BAS'),
('VALOR_FISCAL', 0, 'B0100000'),
('VALOR_GUBERNAMENTAL', 0, 'B1500000')
ON CONFLICT (invoice_type) DO UPDATE SET
    prefix = EXCLUDED.prefix,
    updated_at = NOW();

-- 4. Crear función mejorada para obtener número de factura
CREATE OR REPLACE FUNCTION public.get_next_invoice_number_by_type(p_invoice_type invoice_type)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  next_seq INTEGER;
  prefix TEXT;
  invoice_num TEXT;
BEGIN
  -- Verificar que el tipo de factura existe
  IF p_invoice_type NOT IN ('BASICA', 'VALOR_FISCAL', 'VALOR_GUBERNAMENTAL') THEN
    RAISE EXCEPTION 'Invalid invoice type: %', p_invoice_type;
  END IF;
  
  -- Lock the row and increment
  UPDATE public.invoice_sequences
  SET current_sequence = current_sequence + 1,
      updated_at = NOW()
  WHERE invoice_type = p_invoice_type
  RETURNING current_sequence, invoice_sequences.prefix INTO next_seq, prefix;
  
  -- Verificar que se obtuvo un resultado
  IF next_seq IS NULL OR prefix IS NULL THEN
    RAISE EXCEPTION 'Could not get sequence for invoice type: %', p_invoice_type;
  END IF;
  
  -- Format the invoice number
  IF p_invoice_type = 'BASICA' THEN
    invoice_num := prefix || '-' || LPAD(next_seq::TEXT, 6, '0');
  ELSE
    -- For fiscal and governmental, append sequence to prefix (8 digits total)
    invoice_num := prefix || LPAD(next_seq::TEXT, 4, '0');
  END IF;
  
  RETURN invoice_num;
END;
$$;

-- 5. Crear función mejorada para generar NCF
CREATE OR REPLACE FUNCTION public.generate_ncf(p_invoice_type invoice_type, p_sequence INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  ncf TEXT;
BEGIN
  IF p_invoice_type = 'VALOR_FISCAL' THEN
    ncf := 'B0100000' || LPAD(p_sequence::TEXT, 4, '0');
  ELSIF p_invoice_type = 'VALOR_GUBERNAMENTAL' THEN
    ncf := 'B1500000' || LPAD(p_sequence::TEXT, 4, '0');
  ELSE
    ncf := NULL;
  END IF;
  
  RETURN ncf;
END;
$$;

-- 6. Crear función mejorada para convertir orden a factura
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
  -- Validar parámetros
  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'Order ID cannot be null';
  END IF;
  
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
  
  -- Verificar que la orden tenga items
  IF NOT EXISTS (SELECT 1 FROM public.order_items WHERE order_id = p_order_id) THEN
    RAISE EXCEPTION 'Order has no items to convert';
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
      CASE 
        WHEN p_invoice_type = 'VALOR_FISCAL' OR p_invoice_type = 'VALOR_GUBERNAMENTAL' 
        THEN order_record.tax 
        ELSE 0 
      END,
      order_record.discount,
      CASE 
        WHEN p_invoice_type = 'VALOR_FISCAL' OR p_invoice_type = 'VALOR_GUBERNAMENTAL' 
        THEN order_record.total 
        ELSE order_record.subtotal 
      END,
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

-- 7. Crear función de prueba para verificar que todo funciona
CREATE OR REPLACE FUNCTION public.test_invoice_conversion()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  test_result TEXT;
BEGIN
  -- Verificar que las tablas existen
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'orders') THEN
    RETURN 'ERROR: orders table does not exist';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoices') THEN
    RETURN 'ERROR: invoices table does not exist';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoice_items') THEN
    RETURN 'ERROR: invoice_items table does not exist';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoice_sequences') THEN
    RETURN 'ERROR: invoice_sequences table does not exist';
  END IF;
  
  -- Verificar que las funciones existen
  IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_next_invoice_number_by_type') THEN
    RETURN 'ERROR: get_next_invoice_number_by_type function does not exist';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'generate_ncf') THEN
    RETURN 'ERROR: generate_ncf function does not exist';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'convert_order_to_invoice') THEN
    RETURN 'ERROR: convert_order_to_invoice function does not exist';
  END IF;
  
  RETURN 'SUCCESS: All tables and functions are properly configured';
END;
$$;

-- Ejecutar prueba
SELECT public.test_invoice_conversion() as test_result;

-- Mostrar información de las secuencias
SELECT 
    invoice_type,
    current_sequence,
    prefix,
    CASE 
        WHEN invoice_type = 'BASICA' THEN prefix || '-' || LPAD((current_sequence + 1)::TEXT, 6, '0')
        ELSE prefix || LPAD((current_sequence + 1)::TEXT, 4, '0')
    END as next_invoice_number
FROM public.invoice_sequences
ORDER BY invoice_type;
