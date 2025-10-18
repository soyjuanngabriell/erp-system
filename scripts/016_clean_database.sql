-- Script para limpiar todo el contenido de las tablas
-- ⚠️ ADVERTENCIA: Este script eliminará TODOS los datos de la base de datos
-- Solo ejecutar en desarrollo o cuando se necesite resetear completamente

-- Deshabilitar triggers temporalmente para evitar problemas de dependencias
SET session_replication_role = replica;

-- Eliminar datos de todas las tablas en orden correcto (respetando foreign keys)
DELETE FROM public.payments;
DELETE FROM public.invoice_items;
DELETE FROM public.invoices;
DELETE FROM public.order_items;
DELETE FROM public.orders;
DELETE FROM public.customers;
DELETE FROM public.stock_movements;
DELETE FROM public.products;
DELETE FROM public.profiles;
DELETE FROM public.business_config;

-- Resetear secuencias de invoice_sequences
UPDATE public.invoice_sequences SET current_sequence = 0 WHERE invoice_type = 'BASICA';
UPDATE public.invoice_sequences SET current_sequence = 0 WHERE invoice_type = 'VALOR_FISCAL';
UPDATE public.invoice_sequences SET current_sequence = 0 WHERE invoice_type = 'VALOR_GUBERNAMENTAL';

-- Habilitar triggers nuevamente
SET session_replication_role = DEFAULT;

-- Verificar que las tablas estén vacías
SELECT 
    'payments' as tabla, COUNT(*) as registros FROM public.payments
UNION ALL
SELECT 
    'invoice_items' as tabla, COUNT(*) as registros FROM public.invoice_items
UNION ALL
SELECT 
    'invoices' as tabla, COUNT(*) as registros FROM public.invoices
UNION ALL
SELECT 
    'order_items' as tabla, COUNT(*) as registros FROM public.order_items
UNION ALL
SELECT 
    'orders' as tabla, COUNT(*) as registros FROM public.orders
UNION ALL
SELECT 
    'customers' as tabla, COUNT(*) as registros FROM public.customers
UNION ALL
SELECT 
    'stock_movements' as tabla, COUNT(*) as registros FROM public.stock_movements
UNION ALL
SELECT 
    'products' as tabla, COUNT(*) as registros FROM public.products
UNION ALL
SELECT 
    'profiles' as tabla, COUNT(*) as registros FROM public.profiles
UNION ALL
SELECT 
    'business_config' as tabla, COUNT(*) as registros FROM public.business_config;

-- Mensaje de confirmación
SELECT 'Base de datos limpiada exitosamente. Todas las tablas están vacías.' as resultado;
