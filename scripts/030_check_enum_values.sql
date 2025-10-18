-- =====================================================
-- VERIFICAR VALORES EXACTOS DE LOS ENUMS
-- =====================================================

-- Verificar valores del enum order_status
SELECT 'order_status values:' as info;
SELECT enumlabel FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'order_status')
ORDER BY enumsortorder;

-- Verificar valores del enum payment_status  
SELECT 'payment_status values:' as info;
SELECT enumlabel FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_status')
ORDER BY enumsortorder;

-- Verificar valores del enum invoice_type
SELECT 'invoice_type values:' as info;
SELECT enumlabel FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'invoice_type')
ORDER BY enumsortorder;

-- Verificar valores del enum payment_method
SELECT 'payment_method values:' as info;
SELECT enumlabel FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'payment_method')
ORDER BY enumsortorder;
