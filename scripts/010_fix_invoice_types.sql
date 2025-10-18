-- Check if invoice_type enum exists and handle it gracefully
DO $$ 
BEGIN
    -- Check if the enum type already exists
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_type') THEN
        CREATE TYPE invoice_type AS ENUM ('BASICA', 'VALOR_FISCAL', 'VALOR_GUBERNAMENTAL');
    END IF;
END $$;

-- Add invoice type to invoices table (only if column doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'invoice_type') THEN
        ALTER TABLE public.invoices ADD COLUMN invoice_type invoice_type NOT NULL DEFAULT 'BASICA';
    END IF;
END $$;

-- Add NCF field for fiscal invoices (only if column doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoices' AND column_name = 'ncf') THEN
        ALTER TABLE public.invoices ADD COLUMN ncf TEXT;
    END IF;
END $$;

-- Add sequence configuration to business_config (only if columns don't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'business_config' AND column_name = 'fiscal_sequence') THEN
        ALTER TABLE public.business_config ADD COLUMN fiscal_sequence INTEGER NOT NULL DEFAULT 0;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'business_config' AND column_name = 'governmental_sequence') THEN
        ALTER TABLE public.business_config ADD COLUMN governmental_sequence INTEGER NOT NULL DEFAULT 0;
    END IF;
END $$;

-- Update invoice_counter to support different types (only if column doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'invoice_counter' AND column_name = 'invoice_type') THEN
        ALTER TABLE public.invoice_counter ADD COLUMN invoice_type invoice_type NOT NULL DEFAULT 'BASICA';
    END IF;
END $$;

-- Create separate counters for each invoice type (only if table doesn't exist)
CREATE TABLE IF NOT EXISTS public.invoice_sequences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_type invoice_type NOT NULL UNIQUE,
  current_sequence INTEGER NOT NULL DEFAULT 0,
  prefix TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert initial sequences (only if they don't exist)
INSERT INTO public.invoice_sequences (invoice_type, current_sequence, prefix) VALUES
('BASICA', 0, 'BAS'),
('VALOR_FISCAL', 0, 'B0100000'),
('VALOR_GUBERNAMENTAL', 0, 'B1500000')
ON CONFLICT (invoice_type) DO NOTHING;

-- Create function to get next invoice number by type (replace if exists)
CREATE OR REPLACE FUNCTION public.get_next_invoice_number_by_type(p_invoice_type invoice_type)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  next_seq INTEGER;
  prefix TEXT;
  invoice_num TEXT;
BEGIN
  -- Lock the row and increment
  UPDATE public.invoice_sequences
  SET current_sequence = current_sequence + 1,
      updated_at = NOW()
  WHERE invoice_type = p_invoice_type
  RETURNING current_sequence, invoice_sequences.prefix INTO next_seq, prefix;
  
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

-- Create function to get NCF for fiscal invoices (replace if exists)
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

-- Add trigger to update updated_at for invoice_sequences (only if trigger doesn't exist)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_invoice_sequences_updated_at') THEN
        CREATE TRIGGER update_invoice_sequences_updated_at
          BEFORE UPDATE ON public.invoice_sequences
          FOR EACH ROW
          EXECUTE FUNCTION public.update_updated_at();
    END IF;
END $$;

-- Create indexes for invoice type (only if they don't exist)
CREATE INDEX IF NOT EXISTS idx_invoices_type ON public.invoices(invoice_type);
CREATE INDEX IF NOT EXISTS idx_invoices_ncf ON public.invoices(ncf);
