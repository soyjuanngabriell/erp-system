-- Add invoice type enum
CREATE TYPE invoice_type AS ENUM ('BASICA', 'VALOR_FISCAL', 'VALOR_GUBERNAMENTAL');

-- Add invoice type to invoices table
ALTER TABLE public.invoices 
ADD COLUMN invoice_type invoice_type NOT NULL DEFAULT 'BASICA';

-- Add NCF field for fiscal invoices
ALTER TABLE public.invoices 
ADD COLUMN ncf TEXT;

-- Add sequence configuration to business_config
ALTER TABLE public.business_config 
ADD COLUMN fiscal_sequence INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.business_config 
ADD COLUMN governmental_sequence INTEGER NOT NULL DEFAULT 0;

-- Update invoice_counter to support different types
ALTER TABLE public.invoice_counter 
ADD COLUMN invoice_type invoice_type NOT NULL DEFAULT 'BASICA';

-- Create separate counters for each invoice type
CREATE TABLE IF NOT EXISTS public.invoice_sequences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_type invoice_type NOT NULL UNIQUE,
  current_sequence INTEGER NOT NULL DEFAULT 0,
  prefix TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert initial sequences
INSERT INTO public.invoice_sequences (invoice_type, current_sequence, prefix) VALUES
('BASICA', 0, 'BAS'),
('VALOR_FISCAL', 0, 'B0100000'),
('VALOR_GUBERNAMENTAL', 0, 'B1500000')
ON CONFLICT (invoice_type) DO NOTHING;

-- Create function to get next invoice number by type
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
    -- For fiscal and governmental, append sequence to prefix
    invoice_num := prefix || LPAD(next_seq::TEXT, 4, '0');
  END IF;
  
  RETURN invoice_num;
END;
$$;

-- Create function to get NCF for fiscal invoices
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

-- Add trigger to update updated_at for invoice_sequences
CREATE TRIGGER update_invoice_sequences_updated_at
  BEFORE UPDATE ON public.invoice_sequences
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at();

-- Create index for invoice type
CREATE INDEX IF NOT EXISTS idx_invoices_type ON public.invoices(invoice_type);
CREATE INDEX IF NOT EXISTS idx_invoices_ncf ON public.invoices(ncf);
