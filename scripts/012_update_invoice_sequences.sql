-- Update invoice sequences to correct values
-- Fiscal sequence should be 368 (B0100000368)
-- Governmental sequence should be 225 (B1500000225)

-- Update fiscal sequence
UPDATE public.invoice_sequences 
SET current_sequence = 368,
    updated_at = NOW()
WHERE invoice_type = 'VALOR_FISCAL';

-- Update governmental sequence  
UPDATE public.invoice_sequences 
SET current_sequence = 225,
    updated_at = NOW()
WHERE invoice_type = 'VALOR_GUBERNAMENTAL';

-- Also update business config if it exists
UPDATE public.business_config 
SET fiscal_sequence = 368,
    governmental_sequence = 225,
    updated_at = NOW()
WHERE id IS NOT NULL;
