-- Script to sync invoice sequences from business configuration
-- This ensures that when the business config is updated, the invoice sequences are also updated

-- Create function to sync sequences from business config
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

-- Create trigger to automatically sync sequences when business config is updated
CREATE OR REPLACE FUNCTION public.trigger_sync_invoice_sequences()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- Sync sequences after business config update
  PERFORM public.sync_invoice_sequences_from_config();
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS sync_invoice_sequences_trigger ON public.business_config;

-- Create the trigger
CREATE TRIGGER sync_invoice_sequences_trigger
  AFTER UPDATE ON public.business_config
  FOR EACH ROW
  EXECUTE FUNCTION public.trigger_sync_invoice_sequences();

-- Initial sync of sequences
SELECT public.sync_invoice_sequences_from_config();
