-- Script para verificar y corregir todas las dependencias necesarias para la conversión
-- Este script asegura que todo esté configurado correctamente

-- 1. Verificar que el enum invoice_type existe
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_type') THEN
        CREATE TYPE invoice_type AS ENUM ('BASICA', 'VALOR_FISCAL', 'VALOR_GUBERNAMENTAL');
        RAISE NOTICE 'Created invoice_type enum';
    ELSE
        RAISE NOTICE 'invoice_type enum already exists';
    END IF;
END $$;

-- 2. Verificar que el enum order_status existe y tiene el valor 'Facturada'
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Facturada' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')) THEN
        ALTER TYPE order_status ADD VALUE 'Facturada';
        RAISE NOTICE 'Added Facturada to order_status enum';
    ELSE
        RAISE NOTICE 'Facturada already exists in order_status enum';
    END IF;
END $$;

-- 3. Asegurar que todas las columnas necesarias existen en orders
DO $$ 
BEGIN
    -- invoice_type column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'invoice_type') THEN
        ALTER TABLE public.orders ADD COLUMN invoice_type invoice_type NOT NULL DEFAULT 'BASICA';
        RAISE NOTICE 'Added invoice_type column to orders';
    END IF;
    
    -- payment_amount column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'payment_amount') THEN
        ALTER TABLE public.orders ADD COLUMN payment_amount DECIMAL(10, 2) NOT NULL DEFAULT 0;
        RAISE NOTICE 'Added payment_amount column to orders';
    END IF;
    
    -- pending_amount column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'pending_amount') THEN
        ALTER TABLE public.orders ADD COLUMN pending_amount DECIMAL(10, 2) NOT NULL DEFAULT 0;
        RAISE NOTICE 'Added pending_amount column to orders';
    END IF;
    
    -- invoice_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'orders' AND column_name = 'invoice_id') THEN
        ALTER TABLE public.orders ADD COLUMN invoice_id UUID REFERENCES public.invoices(id) ON DELETE SET NULL;
        RAISE NOTICE 'Added invoice_id column to orders';
    END IF;
END $$;

-- 4. Asegurar que todas las columnas necesarias existen en invoices
DO $$ 
BEGIN
    -- invoice_type column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'invoice_type') THEN
        ALTER TABLE public.invoices ADD COLUMN invoice_type invoice_type NOT NULL DEFAULT 'BASICA';
        RAISE NOTICE 'Added invoice_type column to invoices';
    END IF;
    
    -- ncf column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'ncf') THEN
        ALTER TABLE public.invoices ADD COLUMN ncf TEXT;
        RAISE NOTICE 'Added ncf column to invoices';
    END IF;
    
    -- order_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'order_id') THEN
        ALTER TABLE public.invoices ADD COLUMN order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL;
        RAISE NOTICE 'Added order_id column to invoices';
    END IF;
    
    -- customer_email column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'customer_email') THEN
        ALTER TABLE public.invoices ADD COLUMN customer_email TEXT;
        RAISE NOTICE 'Added customer_email column to invoices';
    END IF;
    
    -- customer_phone column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'customer_phone') THEN
        ALTER TABLE public.invoices ADD COLUMN customer_phone TEXT;
        RAISE NOTICE 'Added customer_phone column to invoices';
    END IF;
END $$;

-- 5. Asegurar que todas las columnas necesarias existen en invoice_items
DO $$ 
BEGIN
    -- product_id column
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoice_items' AND column_name = 'product_id') THEN
        ALTER TABLE public.invoice_items ADD COLUMN product_id UUID REFERENCES public.products(id) ON DELETE SET NULL;
        RAISE NOTICE 'Added product_id column to invoice_items';
    END IF;
END $$;

-- 6. Crear tabla invoice_sequences si no existe
CREATE TABLE IF NOT EXISTS public.invoice_sequences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_type invoice_type NOT NULL UNIQUE,
  current_sequence INTEGER NOT NULL DEFAULT 0,
  prefix TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Insertar secuencias iniciales
INSERT INTO public.invoice_sequences (invoice_type, current_sequence, prefix) VALUES
('BASICA', 0, 'BAS'),
('VALOR_FISCAL', 0, 'B0100000'),
('VALOR_GUBERNAMENTAL', 0, 'B1500000')
ON CONFLICT (invoice_type) DO UPDATE SET
    prefix = EXCLUDED.prefix,
    updated_at = NOW();

-- 8. Crear función get_next_invoice_number_by_type si no existe
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

-- 9. Crear función generate_ncf si no existe
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

-- 10. Crear índices para mejor rendimiento
CREATE INDEX IF NOT EXISTS idx_orders_invoice_type ON public.orders(invoice_type);
CREATE INDEX IF NOT EXISTS idx_orders_invoice_id ON public.orders(invoice_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_invoices_type ON public.invoices(invoice_type);
CREATE INDEX IF NOT EXISTS idx_invoices_order_id ON public.invoices(order_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice_id ON public.invoice_items(invoice_id);

-- 11. Mostrar resumen de configuración
SELECT '=== RESUMEN DE CONFIGURACIÓN ===' as section;

SELECT 
    'invoice_type enum' as component,
    CASE WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_type') THEN 'OK' ELSE 'MISSING' END as status
UNION ALL
SELECT 
    'order_status enum with Facturada' as component,
    CASE WHEN EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Facturada' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')) THEN 'OK' ELSE 'MISSING' END as status
UNION ALL
SELECT 
    'invoice_sequences table' as component,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'invoice_sequences') THEN 'OK' ELSE 'MISSING' END as status
UNION ALL
SELECT 
    'get_next_invoice_number_by_type function' as component,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'get_next_invoice_number_by_type') THEN 'OK' ELSE 'MISSING' END as status
UNION ALL
SELECT 
    'generate_ncf function' as component,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'generate_ncf') THEN 'OK' ELSE 'MISSING' END as status;

-- 12. Mostrar datos de secuencias
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

SELECT 'Configuración completada. Todas las dependencias están listas.' as result;
