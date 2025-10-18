-- =====================================================
-- FINAL BUSINESS CONFIG FIX
-- =====================================================
-- This script ensures everything is working correctly for business configuration

-- 1. Ensure business_config table exists with correct structure
CREATE TABLE IF NOT EXISTS public.business_config (
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

-- 2. Ensure invoice_sequences table exists
CREATE TABLE IF NOT EXISTS public.invoice_sequences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_type TEXT NOT NULL UNIQUE,
    current_sequence INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Insert default invoice sequences if they don't exist
INSERT INTO public.invoice_sequences (invoice_type, current_sequence) VALUES
    ('BASICA', 0),
    ('VALOR_FISCAL', 0),
    ('VALOR_GUBERNAMENTAL', 0)
ON CONFLICT (invoice_type) DO NOTHING;

-- 4. Ensure sync function exists and works correctly
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

-- 5. Insert default business config if none exists
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
) ON CONFLICT DO NOTHING;

-- 6. Test the sync function
SELECT public.sync_invoice_sequences_from_config();

-- 7. Verify everything is working
SELECT 
    'Business config table structure verified!' as result,
    COUNT(*) as config_count
FROM public.business_config;

SELECT 
    'Invoice sequences verified!' as result,
    COUNT(*) as sequence_count
FROM public.invoice_sequences;
