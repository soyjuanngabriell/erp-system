-- Ensure all required fields exist in the orders table
-- This script will add any missing fields that might cause errors

-- Add payment_amount and pending_amount if they don't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'payment_amount') THEN
        ALTER TABLE public.orders ADD COLUMN payment_amount DECIMAL(10, 2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'pending_amount') THEN
        ALTER TABLE public.orders ADD COLUMN pending_amount DECIMAL(10, 2) NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'invoice_id') THEN
        ALTER TABLE public.orders ADD COLUMN invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Update existing orders to calculate pending_amount
UPDATE public.orders 
SET pending_amount = total - COALESCE(payment_amount, 0)
WHERE pending_amount IS NULL OR pending_amount = 0;

-- Ensure the Facturada status exists in the enum
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Facturada' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')) THEN
        ALTER TYPE order_status ADD VALUE 'Facturada';
    END IF;
END $$;

-- Create payments table if it doesn't exist
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

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_date ON public.payments(payment_date DESC);
CREATE INDEX IF NOT EXISTS idx_orders_payment_amount ON public.orders(payment_amount);
CREATE INDEX IF NOT EXISTS idx_orders_pending_amount ON public.orders(pending_amount);
CREATE INDEX IF NOT EXISTS idx_orders_invoice_id ON public.orders(invoice_id);
