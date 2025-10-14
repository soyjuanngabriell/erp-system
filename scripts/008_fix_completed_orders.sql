-- Update existing completed orders to have proper payment_status
-- This script will fix orders that are marked as "Completado" but don't have payment_status set

UPDATE public.orders 
SET payment_status = CASE 
    WHEN deposit_amount IS NULL OR deposit_amount = 0 THEN 'pending'
    WHEN deposit_amount >= total THEN 'paid'
    ELSE 'partial'
END,
updated_at = NOW()
WHERE status = 'Completado' 
AND (payment_status IS NULL OR payment_status = '');

-- Show the results
SELECT 
    order_number,
    status,
    payment_status,
    deposit_amount,
    total,
    CASE 
        WHEN deposit_amount IS NULL OR deposit_amount = 0 THEN 'Sin abono'
        WHEN deposit_amount >= total THEN 'Pagado completamente'
        ELSE 'Abono parcial'
    END as payment_description
FROM public.orders 
WHERE status = 'Completado'
ORDER BY created_at DESC;
