-- Script para corregir el cálculo de ITBIS en órdenes existentes
-- Este script ajusta las órdenes básicas para que no tengan ITBIS

-- Actualizar órdenes básicas para quitar ITBIS
UPDATE public.orders 
SET 
    tax = 0,
    total = subtotal,
    updated_at = NOW()
WHERE invoice_type = 'BASICA' 
AND tax > 0;

-- Mostrar resumen de cambios
SELECT 
    invoice_type,
    COUNT(*) as total_orders,
    SUM(CASE WHEN tax > 0 THEN 1 ELSE 0 END) as orders_with_tax,
    SUM(CASE WHEN tax = 0 THEN 1 ELSE 0 END) as orders_without_tax,
    AVG(tax) as avg_tax,
    AVG(total) as avg_total
FROM public.orders
GROUP BY invoice_type
ORDER BY invoice_type;

-- Mostrar algunas órdenes básicas para verificar
SELECT 
    order_number,
    invoice_type,
    subtotal,
    tax,
    total,
    CASE 
        WHEN invoice_type = 'BASICA' AND tax = 0 THEN 'CORRECTO'
        WHEN invoice_type = 'BASICA' AND tax > 0 THEN 'INCORRECTO'
        WHEN invoice_type IN ('VALOR_FISCAL', 'VALOR_GUBERNAMENTAL') AND tax > 0 THEN 'CORRECTO'
        ELSE 'REVISAR'
    END as estado_calculo
FROM public.orders
WHERE invoice_type = 'BASICA'
ORDER BY created_at DESC
LIMIT 10;

-- Mensaje de confirmación
SELECT 'Órdenes básicas corregidas: ITBIS eliminado, total ajustado al subtotal.' as resultado;
