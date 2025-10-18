-- Add invoice_type field to orders table
-- This field will store the type of invoice that should be generated when converting the order

-- Add invoice_type column to orders table
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'invoice_type') THEN
        ALTER TABLE public.orders ADD COLUMN invoice_type invoice_type NOT NULL DEFAULT 'BASICA';
    END IF;
END $$;

-- Update existing orders to have BASICA as default invoice type
UPDATE public.orders 
SET invoice_type = 'BASICA'
WHERE invoice_type IS NULL;

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_orders_invoice_type ON public.orders(invoice_type);

-- Show the updated structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND column_name = 'invoice_type';

-- Show count of orders by invoice type
SELECT 
    invoice_type,
    COUNT(*) as order_count
FROM public.orders
GROUP BY invoice_type
ORDER BY invoice_type;
