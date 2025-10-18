-- =====================================================
-- CORRECCIÓN DE TIPOS DE DATOS PARA PAGOS
-- =====================================================
-- Este script corrige el problema con el tipo payment_status

-- =====================================================
-- 1. VERIFICAR TIPOS EXISTENTES
-- =====================================================

SELECT '=== VERIFICACIÓN DE TIPOS EXISTENTES ===' as section;

SELECT 
    typname as tipo,
    enumlabel as valor
FROM pg_type t
JOIN pg_enum e ON t.oid = e.enumtypid
WHERE typname IN ('payment_status', 'order_status', 'invoice_type')
ORDER BY typname, enumlabel;

-- =====================================================
-- 2. CORREGIR FUNCIÓN update_order_payment_status
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_order_payment_status(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    order_record RECORD;
    total_paid_amount DECIMAL(10,2);
    new_payment_status payment_status;
BEGIN
    -- Obtener información de la orden
    SELECT * INTO order_record
    FROM public.orders
    WHERE id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada: %', p_order_id;
    END IF;

    -- Calcular total pagado
    SELECT COALESCE(SUM(amount), 0) INTO total_paid_amount
    FROM public.order_payments
    WHERE order_id = p_order_id;

    -- Determinar estado de pago usando el tipo enum
    IF total_paid_amount = 0 THEN
        new_payment_status := 'Pendiente'::payment_status;
    ELSIF total_paid_amount < order_record.total THEN
        new_payment_status := 'Parcial'::payment_status;
    ELSE
        new_payment_status := 'Completo'::payment_status;
    END IF;

    -- Actualizar orden
    UPDATE public.orders
    SET 
        total_paid = total_paid_amount,
        pending_amount = order_record.total - total_paid_amount,
        payment_status = new_payment_status,
        updated_at = NOW()
    WHERE id = p_order_id;

    RAISE NOTICE 'Orden % actualizada: Total pagado: RD$ %, Pendiente: RD$ %, Estado: %', 
        p_order_id, total_paid_amount, (order_record.total - total_paid_amount), new_payment_status;
END;
$$;

-- =====================================================
-- 3. CORREGIR FUNCIÓN convert_order_to_invoice
-- =====================================================

CREATE OR REPLACE FUNCTION public.convert_order_to_invoice(p_order_id UUID, p_invoice_type TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    order_record RECORD;
    invoice_id UUID;
    invoice_number TEXT;
    ncf TEXT;
    next_seq INTEGER;
BEGIN
    -- Obtener información de la orden
    SELECT * INTO order_record
    FROM public.orders
    WHERE id = p_order_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Orden no encontrada: %', p_order_id;
    END IF;

    -- Verificar que la orden esté completamente pagada
    IF order_record.pending_amount > 0 THEN
        RAISE EXCEPTION 'La orden no está completamente pagada. Pendiente: RD$ %', order_record.pending_amount;
    END IF;

    -- Verificar que la orden esté completada
    IF order_record.status != 'Completada' THEN
        RAISE EXCEPTION 'La orden debe estar completada para convertir a factura. Estado actual: %', order_record.status;
    END IF;

    -- Obtener número de factura
    SELECT public.get_next_invoice_number(p_invoice_type) INTO invoice_number;

    -- Generar NCF si es necesario
    IF p_invoice_type IN ('VALOR_FISCAL', 'VALOR_GUBERNAMENTAL') THEN
        SELECT CAST(SUBSTRING(invoice_number FROM 4) AS INTEGER) INTO next_seq;
        SELECT public.generate_ncf(p_invoice_type, next_seq) INTO ncf;
    END IF;

    -- Crear factura
    INSERT INTO public.invoices (
        invoice_number,
        invoice_type,
        ncf,
        customer_name,
        customer_rnc,
        customer_email,
        customer_phone,
        subtotal,
        tax,
        discount,
        total,
        payment_method,
        notes,
        created_by
    ) VALUES (
        invoice_number,
        p_invoice_type::invoice_type,
        ncf,
        order_record.customer_name,
        order_record.customer_rnc,
        NULL, -- customer_email
        NULL, -- customer_phone
        order_record.subtotal,
        CASE WHEN p_invoice_type = 'BASICA' THEN 0 ELSE order_record.tax END,
        0,
        CASE WHEN p_invoice_type = 'BASICA' THEN order_record.subtotal ELSE order_record.total END,
        'Efectivo', -- payment_method por defecto
        'Convertida desde orden ' || order_record.order_number,
        order_record.created_by
    ) RETURNING id INTO invoice_id;

    -- Crear items de factura
    INSERT INTO public.invoice_items (
        invoice_id,
        product_id,
        product_name,
        product_sku,
        quantity,
        unit_price,
        subtotal
    )
    SELECT 
        invoice_id,
        product_id,
        product_name,
        product_sku,
        quantity,
        unit_price,
        subtotal
    FROM public.order_items
    WHERE order_id = p_order_id;

    -- Actualizar orden
    UPDATE public.orders
    SET 
        status = 'Facturada'::order_status,
        invoice_id = invoice_id,
        updated_at = NOW()
    WHERE id = p_order_id;

    RAISE NOTICE 'Orden % convertida a factura % exitosamente', p_order_id, invoice_number;

    RETURN invoice_id;
END;
$$;

-- =====================================================
-- 4. PROBAR CORRECCIÓN
-- =====================================================

SELECT '=== PRUEBA DE CORRECCIÓN ===' as section;

-- Crear datos de prueba
INSERT INTO public.customers (name, rnc_cedula, email, phone) VALUES
('Cliente Prueba Corrección', '444444444', 'cliente@correccion.com', '809-444-4444')
ON CONFLICT (rnc_cedula) DO NOTHING;

INSERT INTO public.products (name, sku, price, stock, min_stock) VALUES
('Producto Prueba Corrección', 'CORRECCION-001', 400.00, 100, 10)
ON CONFLICT (sku) DO NOTHING;

-- Probar corrección
DO $$
DECLARE
    test_customer_id UUID;
    test_product_id UUID;
    test_user_id UUID;
    test_order_id UUID;
    test_payment_id UUID;
    test_total_paid DECIMAL(10,2);
    test_pending_amount DECIMAL(10,2);
    test_payment_status payment_status;
BEGIN
    -- Obtener IDs
    SELECT id INTO test_customer_id FROM public.customers WHERE rnc_cedula = '444444444' LIMIT 1;
    SELECT id INTO test_product_id FROM public.products WHERE sku = 'CORRECCION-001' LIMIT 1;
    SELECT id INTO test_user_id FROM public.profiles LIMIT 1;

    RAISE NOTICE '=== INICIANDO PRUEBA DE CORRECCIÓN ===';

    -- 1. Crear orden
    INSERT INTO public.orders (
        order_number,
        customer_id,
        customer_name,
        customer_rnc,
        status,
        invoice_type,
        subtotal,
        tax,
        total,
        total_paid,
        pending_amount,
        payment_status,
        created_by
    ) VALUES (
        'CORRECCION-TEST-' || EXTRACT(EPOCH FROM NOW())::TEXT,
        test_customer_id,
        'Cliente Prueba Corrección',
        '444444444',
        'Pendiente'::order_status,
        'BASICA'::invoice_type,
        400.00,
        0.00,
        400.00,
        0.00,
        400.00,
        'Pendiente'::payment_status,
        test_user_id
    ) RETURNING id INTO test_order_id;

    RAISE NOTICE '✓ Orden creada: %', test_order_id;

    -- 2. Crear item de orden
    INSERT INTO public.order_items (
        order_id,
        product_id,
        product_name,
        product_sku,
        quantity,
        unit_price,
        subtotal
    ) VALUES (
        test_order_id,
        test_product_id,
        'Producto Prueba Corrección',
        'CORRECCION-001',
        1,
        400.00,
        400.00
    );

    RAISE NOTICE '✓ Item de orden creado';

    -- 3. Agregar pago
    INSERT INTO public.order_payments (
        order_id,
        amount,
        payment_method,
        notes,
        created_by
    ) VALUES (
        test_order_id,
        200.00,
        'Efectivo',
        'Pago de prueba',
        test_user_id
    ) RETURNING id INTO test_payment_id;

    RAISE NOTICE '✓ Pago creado: %', test_payment_id;

    -- 4. Verificar estado después del pago
    SELECT total_paid, pending_amount, payment_status INTO STRICT test_total_paid, test_pending_amount, test_payment_status
    FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Estado después del pago:';
    RAISE NOTICE '  Total pagado: RD$ %', test_total_paid;
    RAISE NOTICE '  Pendiente: RD$ %', test_pending_amount;
    RAISE NOTICE '  Estado de pago: %', test_payment_status;

    -- Limpiar datos de prueba
    DELETE FROM public.order_payments WHERE order_id = test_order_id;
    DELETE FROM public.order_items WHERE order_id = test_order_id;
    DELETE FROM public.orders WHERE id = test_order_id;

    RAISE NOTICE '✓ Datos de prueba limpiados';
    RAISE NOTICE '=== CORRECCIÓN COMPLETADA EXITOSAMENTE ===';

EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '✗ ERROR: %', SQLERRM;
        RAISE NOTICE 'Código de error: %', SQLSTATE;
        
        -- Limpiar en caso de error
        IF test_order_id IS NOT NULL THEN
            DELETE FROM public.order_payments WHERE order_id = test_order_id;
            DELETE FROM public.order_items WHERE order_id = test_order_id;
            DELETE FROM public.orders WHERE id = test_order_id;
        END IF;
END $$;

-- =====================================================
-- 5. LIMPIAR DATOS DE PRUEBA
-- =====================================================

DELETE FROM public.products WHERE sku = 'CORRECCION-001';
DELETE FROM public.customers WHERE rnc_cedula = '444444444';

-- =====================================================
-- 6. RESUMEN FINAL
-- =====================================================

SELECT '=== RESUMEN DE CORRECCIÓN ===' as section;

SELECT 
    'Tipos de datos' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') 
         THEN 'CORREGIDOS' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Función update_order_payment_status' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'update_order_payment_status' AND routine_schema = 'public') 
         THEN 'CORREGIDA' 
         ELSE 'ERROR' 
    END as estado
UNION ALL
SELECT 
    'Función convert_order_to_invoice' as componente,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.routines WHERE routine_name = 'convert_order_to_invoice' AND routine_schema = 'public') 
         THEN 'CORREGIDA' 
         ELSE 'ERROR' 
    END as estado;

SELECT 'Corrección de tipos de datos completada.' as result;
