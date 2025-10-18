-- =====================================================
-- FIX BUSINESS CONFIG TABLE STRUCTURE INCONSISTENCY
-- =====================================================
-- This script fixes the inconsistency between different business_config table structures
-- and ensures the table has the correct fields that match the form

-- First, let's check what fields currently exist
DO $$
DECLARE
    column_exists BOOLEAN;
BEGIN
    -- Check if business_name column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'business_config' 
        AND column_name = 'business_name'
        AND table_schema = 'public'
    ) INTO column_exists;
    
    -- If business_name doesn't exist but company_name does, rename it
    IF NOT column_exists THEN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'business_config' 
            AND column_name = 'company_name'
            AND table_schema = 'public'
        ) INTO column_exists;
        
        IF column_exists THEN
            ALTER TABLE public.business_config RENAME COLUMN company_name TO business_name;
            RAISE NOTICE 'Renamed company_name to business_name';
        END IF;
    END IF;
    
    -- Check if rnc column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'business_config' 
        AND column_name = 'rnc'
        AND table_schema = 'public'
    ) INTO column_exists;
    
    -- If rnc doesn't exist but company_rnc does, rename it
    IF NOT column_exists THEN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'business_config' 
            AND column_name = 'company_rnc'
            AND table_schema = 'public'
        ) INTO column_exists;
        
        IF column_exists THEN
            ALTER TABLE public.business_config RENAME COLUMN company_rnc TO rnc;
            RAISE NOTICE 'Renamed company_rnc to rnc';
        END IF;
    END IF;
    
    -- Check if address column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'business_config' 
        AND column_name = 'address'
        AND table_schema = 'public'
    ) INTO column_exists;
    
    -- If address doesn't exist but company_address does, rename it
    IF NOT column_exists THEN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'business_config' 
            AND column_name = 'company_address'
            AND table_schema = 'public'
        ) INTO column_exists;
        
        IF column_exists THEN
            ALTER TABLE public.business_config RENAME COLUMN company_address TO address;
            RAISE NOTICE 'Renamed company_address to address';
        END IF;
    END IF;
    
    -- Check if phone column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'business_config' 
        AND column_name = 'phone'
        AND table_schema = 'public'
    ) INTO column_exists;
    
    -- If phone doesn't exist but company_phone does, rename it
    IF NOT column_exists THEN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'business_config' 
            AND column_name = 'company_phone'
            AND table_schema = 'public'
        ) INTO column_exists;
        
        IF column_exists THEN
            ALTER TABLE public.business_config RENAME COLUMN company_phone TO phone;
            RAISE NOTICE 'Renamed company_phone to phone';
        END IF;
    END IF;
    
    -- Check if email column exists
    SELECT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'business_config' 
        AND column_name = 'email'
        AND table_schema = 'public'
    ) INTO column_exists;
    
    -- If email doesn't exist but company_email does, rename it
    IF NOT column_exists THEN
        SELECT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'business_config' 
            AND column_name = 'company_email'
            AND table_schema = 'public'
        ) INTO column_exists;
        
        IF column_exists THEN
            ALTER TABLE public.business_config RENAME COLUMN company_email TO email;
            RAISE NOTICE 'Renamed company_email to email';
        END IF;
    END IF;
END $$;

-- Ensure all required columns exist with correct names
DO $$
BEGIN
    -- Add business_name if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'business_name' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN business_name TEXT;
        RAISE NOTICE 'Added business_name column';
    END IF;
    
    -- Add rnc if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'rnc' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN rnc TEXT;
        RAISE NOTICE 'Added rnc column';
    END IF;
    
    -- Add address if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'address' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN address TEXT;
        RAISE NOTICE 'Added address column';
    END IF;
    
    -- Add phone if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'phone' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN phone TEXT;
        RAISE NOTICE 'Added phone column';
    END IF;
    
    -- Add email if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'email' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN email TEXT;
        RAISE NOTICE 'Added email column';
    END IF;
    
    -- Add logo_url if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'logo_url' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN logo_url TEXT;
        RAISE NOTICE 'Added logo_url column';
    END IF;
    
    -- Add low_stock_threshold if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'low_stock_threshold' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN low_stock_threshold INTEGER NOT NULL DEFAULT 10;
        RAISE NOTICE 'Added low_stock_threshold column';
    END IF;
    
    -- Add fiscal_sequence if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'fiscal_sequence' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN fiscal_sequence INTEGER NOT NULL DEFAULT 0;
        RAISE NOTICE 'Added fiscal_sequence column';
    END IF;
    
    -- Add governmental_sequence if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'governmental_sequence' AND table_schema = 'public') THEN
        ALTER TABLE public.business_config ADD COLUMN governmental_sequence INTEGER NOT NULL DEFAULT 0;
        RAISE NOTICE 'Added governmental_sequence column';
    END IF;
END $$;

-- Update any existing data to use the correct column names
DO $$
BEGIN
    -- If we have data in old columns, copy it to new columns
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'company_name' AND table_schema = 'public') THEN
        UPDATE public.business_config 
        SET business_name = company_name 
        WHERE business_name IS NULL AND company_name IS NOT NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'company_rnc' AND table_schema = 'public') THEN
        UPDATE public.business_config 
        SET rnc = company_rnc 
        WHERE rnc IS NULL AND company_rnc IS NOT NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'company_address' AND table_schema = 'public') THEN
        UPDATE public.business_config 
        SET address = company_address 
        WHERE address IS NULL AND company_address IS NOT NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'company_phone' AND table_schema = 'public') THEN
        UPDATE public.business_config 
        SET phone = company_phone 
        WHERE phone IS NULL AND company_phone IS NOT NULL;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'business_config' AND column_name = 'company_email' AND table_schema = 'public') THEN
        UPDATE public.business_config 
        SET email = company_email 
        WHERE email IS NULL AND company_email IS NOT NULL;
    END IF;
END $$;

-- Ensure the sync function exists and works correctly
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
SELECT 'Business config table structure fixed successfully!' as result;
