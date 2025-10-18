-- =====================================================
-- QUICK FIX FOR BUSINESS CONFIG TABLE
-- =====================================================
-- This script ensures the business_config table has the correct structure

-- Drop and recreate the table with the correct structure
DROP TABLE IF EXISTS public.business_config CASCADE;

CREATE TABLE public.business_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_name TEXT NOT NULL,
    rnc TEXT NOT NULL,
    address TEXT NOT NULL,
    phone TEXT NOT NULL,
    email TEXT NOT NULL,
    logo_url TEXT,
    low_stock_threshold INTEGER NOT NULL DEFAULT 10,
    fiscal_sequence INTEGER NOT NULL DEFAULT 0,
    governmental_sequence INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Insert default configuration
INSERT INTO public.business_config (
    business_name,
    rnc,
    address,
    phone,
    email,
    low_stock_threshold,
    fiscal_sequence,
    governmental_sequence
) VALUES (
    'Mi Empresa',
    '000-0000000-0',
    'Calle Principal #123, Santo Domingo',
    '809-000-0000',
    'info@miempresa.com',
    10,
    0,
    0
);

-- Ensure the sync function exists
CREATE OR REPLACE FUNCTION public.sync_invoice_sequences_from_config()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  config_record RECORD;
BEGIN
  -- Get the business configuration
  SELECT fiscal_sequence, governmental_sequence 
  INTO config_record
  FROM public.business_config 
  LIMIT 1;
  
  -- Update fiscal sequence if config exists
  IF config_record IS NOT NULL THEN
    UPDATE public.invoice_sequences 
    SET current_sequence = config_record.fiscal_sequence,
        updated_at = NOW()
    WHERE invoice_type = 'VALOR_FISCAL';
    
    -- Update governmental sequence if config exists
    UPDATE public.invoice_sequences 
    SET current_sequence = config_record.governmental_sequence,
        updated_at = NOW()
    WHERE invoice_type = 'VALOR_GUBERNAMENTAL';
  END IF;
END;
$$;

-- Test the function
SELECT 'Business config table recreated successfully!' as result;
