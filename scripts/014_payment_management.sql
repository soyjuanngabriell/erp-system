-- Add payment management fields to orders table
ALTER TABLE public.orders 
ADD COLUMN payment_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
ADD COLUMN pending_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
ADD COLUMN invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL;

-- Update order_status enum to include Facturada
ALTER TYPE order_status ADD VALUE 'Facturada';

-- Create payments table for tracking payment history
CREATE TABLE IF NOT EXISTS public.payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  amount DECIMAL(10, 2) NOT NULL,
  payment_method payment_method NOT NULL,
  payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  notes TEXT,
  created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for payments
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON public.payments(payment_date DESC);

-- Function to calculate pending amount for an order
CREATE OR REPLACE FUNCTION public.calculate_order_pending_amount(p_order_id UUID)
RETURNS DECIMAL(10, 2)
LANGUAGE plpgsql
AS $$
DECLARE
  order_total DECIMAL(10, 2);
  total_payments DECIMAL(10, 2);
BEGIN
  -- Get order total
  SELECT total INTO order_total
  FROM public.orders
  WHERE id = p_order_id;
  
  -- Get total payments
  SELECT COALESCE(SUM(amount), 0) INTO total_payments
  FROM public.payments
  WHERE order_id = p_order_id;
  
  RETURN order_total - total_payments;
END;
$$;

-- Function to convert order to invoice
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
  prefix TEXT;
BEGIN
  -- Get order details
  SELECT * INTO order_record
  FROM public.orders
  WHERE id = p_order_id;
  
  IF order_record IS NULL THEN
    RAISE EXCEPTION 'Order not found';
  END IF;
  
  -- Get next invoice number
  SELECT public.get_next_invoice_number_by_type(p_invoice_type) INTO invoice_number;
  
  -- Generate NCF for fiscal invoices
  IF p_invoice_type = 'VALOR_FISCAL' OR p_invoice_type = 'VALOR_GUBERNAMENTAL' THEN
    SELECT public.generate_ncf(p_invoice_type, next_seq) INTO ncf;
  END IF;
  
  -- Create invoice
  INSERT INTO public.invoices (
    invoice_number,
    invoice_type,
    ncf,
    order_id,
    customer_name,
    customer_rnc,
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
    order_record.subtotal,
    order_record.tax,
    order_record.discount,
    order_record.total,
    order_record.payment_method,
    order_record.notes,
    order_record.created_by
  ) RETURNING id INTO invoice_id;
  
  -- Create invoice items from order items
  INSERT INTO public.invoice_items (
    invoice_id,
    product_name,
    product_sku,
    quantity,
    unit_price,
    subtotal
  )
  SELECT 
    invoice_id,
    product_name,
    product_sku,
    quantity,
    unit_price,
    subtotal
  FROM public.order_items
  WHERE order_id = p_order_id;
  
  -- Update order with invoice reference and status
  UPDATE public.orders
  SET invoice_id = invoice_id,
      status = 'Facturada',
      updated_at = NOW()
  WHERE id = p_order_id;
  
  RETURN invoice_id;
END;
$$;
