-- =====================================================
-- CORRECCIÓN DE ERRORES EN PAGOS Y FACTURACIÓN
-- =====================================================
-- Este script corrige los errores más comunes que están
-- causando problemas en el registro de pagos y creación de facturas

-- =====================================================
-- 1. VERIFICAR Y CORREGIR ESTRUCTURA DE TABLAS
-- =====================================================

-- Verificar si la tabla orders tiene los campos correctos
DO $$
BEGIN
    -- Agregar total_paid si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'total_paid'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN total_paid DECIMAL(10,2) DEFAULT 0.00;
        RAISE NOTICE 'Campo total_paid agregado a la tabla orders';
    END IF;

    -- Agregar pending_amount si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'pending_amount'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN pending_amount DECIMAL(10,2) DEFAULT 0.00;
        RAISE NOTICE 'Campo pending_amount agregado a la tabla orders';
    END IF;

    -- Agregar payment_status si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'payment_status'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN payment_status TEXT DEFAULT 'Pendiente';
        RAISE NOTICE 'Campo payment_status agregado a la tabla orders';
    END IF;

    -- Agregar invoice_id si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'invoice_id'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN invoice_id UUID REFERENCES public.invoices(id);
        RAISE NOTICE 'Campo invoice_id agregado a la tabla orders';
    END IF;

    -- Agregar invoice_type si no existe
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'orders' 
        AND column_name = 'invoice_type'
        AND table_schema = 'public'
    ) THEN
        ALTER TABLE public.orders ADD COLUMN invoice_type TEXT DEFAULT 'BASICA';
        RAISE NOTICE 'Campo invoice_type agregado a la tabla orders';
    END IF;
END $$;

-- =====================================================
-- 2. CREAR FUNCIÓN update_order_payment_status SI NO EXISTE
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_order_payment_status(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    order_record RECORD;
    total_paid_amount DECIMAL(10,2);
    new_payment_status TEXT;
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

    -- Determinar estado de pago
    IF total_paid_amount = 0 THEN
        new_payment_status := 'Pendiente';
    ELSIF total_paid_amount < order_record.total THEN
        new_payment_status := 'Parcial';
    ELSE
        new_payment_status := 'Completo';
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
-- 3. CREAR TRIGGER PARA ACTUALIZAR PAGOS AUTOMÁTICAMENTE
-- =====================================================

-- Eliminar trigger existente si existe
DROP TRIGGER IF EXISTS trigger_update_order_payment_status ON public.order_payments;

-- Crear trigger
CREATE TRIGGER trigger_update_order_payment_status
    AFTER INSERT OR UPDATE OR DELETE ON public.order_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.update_order_payment_status(
        CASE 
            WHEN TG_OP = 'DELETE' THEN OLD.order_id
            ELSE NEW.order_id
        END
    );

-- =====================================================
-- 4. CREAR FUNCIÓN get_next_invoice_number SI NO EXISTE
-- =====================================================

CREATE OR REPLACE FUNCTION public.get_next_invoice_number(p_invoice_type TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    next_seq INTEGER;
    invoice_number TEXT;
    prefix TEXT;
BEGIN
    -- Determinar prefijo según tipo
    CASE p_invoice_type
        WHEN 'BASICA' THEN prefix := 'B01';
        WHEN 'VALOR_FISCAL' THEN prefix := 'B02';
        WHEN 'VALOR_GUBERNAMENTAL' THEN prefix := 'B15';
        ELSE prefix := 'B01';
    END CASE;

    -- Obtener siguiente secuencia
    SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number FROM 4) AS INTEGER)), 0) + 1
    INTO next_seq
    FROM public.invoices
    WHERE invoice_type = p_invoice_type;

    -- Formatear número de factura (8 dígitos)
    invoice_number := prefix || LPAD(next_seq::TEXT, 5, '0');

    RETURN invoice_number;
END;
$$;

-- =====================================================
-- 5. CREAR FUNCIÓN generate_ncf SI NO EXISTE
-- =====================================================

CREATE OR REPLACE FUNCTION public.generate_ncf(p_invoice_type TEXT, p_sequence INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    ncf TEXT;
    prefix TEXT;
    formatted_seq TEXT;
BEGIN
    -- Determinar prefijo según tipo
    CASE p_invoice_type
        WHEN 'VALOR_FISCAL' THEN prefix := 'B02';
        WHEN 'VALOR_GUBERNAMENTAL' THEN prefix := 'B15';
        ELSE 
            RAISE EXCEPTION 'Tipo de factura no válido para NCF: %', p_invoice_type;
    END CASE;

    -- Formatear secuencia (8 dígitos)
    formatted_seq := LPAD(p_sequence::TEXT, 8, '0');

    -- Generar NCF
    ncf := prefix || formatted_seq;

    RETURN ncf;
END;
$$;

-- =====================================================
-- 6. CREAR FUNCIÓN convert_order_to_invoice SI NO EXISTE
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
        p_invoice_type,
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
        status = 'Facturada',
        invoice_id = invoice_id,
        updated_at = NOW()
    WHERE id = p_order_id;

    RAISE NOTICE 'Orden % convertida a factura % exitosamente', p_order_id, invoice_number;

    RETURN invoice_id;
END;
$$;

-- =====================================================
-- 7. ACTUALIZAR ÓRDENES EXISTENTES
-- =====================================================

-- Actualizar órdenes existentes que no tengan los campos nuevos
UPDATE public.orders
SET 
    total_paid = COALESCE(total_paid, 0),
    pending_amount = COALESCE(pending_amount, total - COALESCE(total_paid, 0)),
    payment_status = CASE 
        WHEN COALESCE(total_paid, 0) = 0 THEN 'Pendiente'
        WHEN COALESCE(total_paid, 0) < total THEN 'Parcial'
        ELSE 'Completo'
    END,
    invoice_type = COALESCE(invoice_type, 'BASICA')
WHERE total_paid IS NULL OR pending_amount IS NULL OR payment_status IS NULL OR invoice_type IS NULL;

-- =====================================================
-- 8. VERIFICAR CORRECCIONES
-- =====================================================

SELECT '=== VERIFICACIÓN DE CORRECCIONES ===' as section;

-- Verificar estructura de tabla orders
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'orders' 
AND table_schema = 'public'
AND column_name IN ('total_paid', 'pending_amount', 'payment_status', 'invoice_id', 'invoice_type')
ORDER BY ordinal_position;

-- Verificar funciones
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name IN (
    'update_order_payment_status',
    'get_next_invoice_number',
    'generate_ncf',
    'convert_order_to_invoice'
)
ORDER BY routine_name;

-- Verificar trigger
SELECT 
    trigger_name,
    event_object_table,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'order_payments'
AND event_object_schema = 'public';

-- Verificar órdenes actualizadas
SELECT 
    COUNT(*) as total_orders,
    COUNT(CASE WHEN total_paid IS NOT NULL THEN 1 END) as with_total_paid,
    COUNT(CASE WHEN pending_amount IS NOT NULL THEN 1 END) as with_pending_amount,
    COUNT(CASE WHEN payment_status IS NOT NULL THEN 1 END) as with_payment_status,
    COUNT(CASE WHEN invoice_type IS NOT NULL THEN 1 END) as with_invoice_type
FROM public.orders;

SELECT 'Correcciones aplicadas exitosamente.' as result;
