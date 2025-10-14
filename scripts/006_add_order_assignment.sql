-- Add assigned user and assignment tracking to orders table
ALTER TABLE public.orders 
ADD COLUMN assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
ADD COLUMN assigned_at TIMESTAMPTZ,
ADD COLUMN customer_email TEXT,
ADD COLUMN customer_phone TEXT,
ADD COLUMN deposit_amount DECIMAL(10, 2) DEFAULT 0,
ADD COLUMN deposit_percentage DECIMAL(5, 2) DEFAULT 0,
ADD COLUMN payment_status TEXT DEFAULT 'pending' CHECK (payment_status IN ('pending', 'partial', 'paid'));

-- Create index for assigned_to for better performance
CREATE INDEX IF NOT EXISTS idx_orders_assigned_to ON public.orders(assigned_to);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);

-- Update existing orders to set created_by if not set (for existing data)
UPDATE public.orders 
SET created_by = (
  SELECT id FROM public.profiles 
  WHERE role = 'Admin' 
  LIMIT 1
)
WHERE created_by IS NULL;
