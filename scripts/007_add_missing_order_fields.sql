-- Add missing fields to orders table (only fields that don't exist)
-- Check if columns exist before adding them

-- Add deposit_amount if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'deposit_amount') THEN
        ALTER TABLE public.orders ADD COLUMN deposit_amount DECIMAL(10, 2) DEFAULT 0;
    END IF;
END $$;

-- Add deposit_percentage if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'deposit_percentage') THEN
        ALTER TABLE public.orders ADD COLUMN deposit_percentage DECIMAL(5, 2) DEFAULT 0;
    END IF;
END $$;

-- Add payment_status if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'payment_status') THEN
        ALTER TABLE public.orders ADD COLUMN payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'partial', 'paid'));
    END IF;
END $$;

-- Create indexes if they don't exist
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);

-- Update existing orders to set created_by if not set (for existing data)
UPDATE public.orders 
SET created_by = (
  SELECT id FROM public.profiles 
  WHERE role = 'Admin' 
  LIMIT 1
)
WHERE created_by IS NULL;
