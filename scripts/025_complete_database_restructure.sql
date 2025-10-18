-- =====================================================
-- SISTEMA ERP/POS - ESTRUCTURA DE BASE DE DATOS COMPLETA
-- =====================================================
-- Este script elimina toda la estructura existente y crea una nueva
-- estructura limpia, coherente y lista para producción.

-- ⚠️ ADVERTENCIA: Este script eliminará TODOS los datos existentes
-- Solo ejecutar en desarrollo o cuando se necesite resetear completamente

-- =====================================================
-- 1. ELIMINAR ESTRUCTURA EXISTENTE
-- =====================================================

-- Deshabilitar triggers temporalmente
SET session_replication_role = replica;

-- Eliminar tablas en orden correcto (respetando foreign keys)
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.invoice_items CASCADE;
DROP TABLE IF EXISTS public.invoices CASCADE;
DROP TABLE IF EXISTS public.order_payments CASCADE;
DROP TABLE IF EXISTS public.order_items CASCADE;
DROP TABLE IF EXISTS public.orders CASCADE;
DROP TABLE IF EXISTS public.customers CASCADE;
DROP TABLE IF EXISTS public.stock_movements CASCADE;
DROP TABLE IF EXISTS public.products CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.business_config CASCADE;
DROP TABLE IF EXISTS public.invoice_sequences CASCADE;
DROP TABLE IF EXISTS public.invoice_counter CASCADE;

-- Eliminar tipos personalizados
DROP TYPE IF EXISTS order_status CASCADE;
DROP TYPE IF EXISTS invoice_type CASCADE;
DROP TYPE IF EXISTS payment_method CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS stock_movement_type CASCADE;

-- Habilitar triggers nuevamente
SET session_replication_role = DEFAULT;

-- =====================================================
-- 2. CREAR TIPOS PERSONALIZADOS
-- =====================================================

-- Estados de órdenes
CREATE TYPE order_status AS ENUM (
    'Pendiente',      -- Orden creada, esperando asignación
    'Asignada',       -- Orden asignada a un vendedor
    'En Proceso',     -- Orden en desarrollo
    'Completada',     -- Orden terminada, lista para facturar
    'Facturada',      -- Orden convertida a factura
    'Cancelada'       -- Orden cancelada
);

-- Tipos de factura
CREATE TYPE invoice_type AS ENUM (
    'BASICA',              -- Factura básica (sin ITBIS)
    'VALOR_FISCAL',        -- Factura fiscal (con ITBIS)
    'VALOR_GUBERNAMENTAL'  -- Factura gubernamental (con ITBIS)
);

-- Métodos de pago
CREATE TYPE payment_method AS ENUM (
    'Efectivo',
    'Tarjeta',
    'Transferencia',
    'Cheque'
);

-- Estados de pago
CREATE TYPE payment_status AS ENUM (
    'Pendiente',    -- Sin pagos
    'Parcial',      -- Pago parcial
    'Completo'      -- Pago completo
);

-- Tipos de movimiento de stock
CREATE TYPE stock_movement_type AS ENUM (
    'ENTRADA',      -- Compra, ajuste positivo
    'SALIDA',       -- Venta, ajuste negativo
    'AJUSTE'        -- Ajuste manual
);

-- =====================================================
-- 3. CREAR TABLAS PRINCIPALES
-- =====================================================

-- Tabla de perfiles de usuario
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('Admin', 'Vendedor')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de configuración de negocio
CREATE TABLE public.business_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_name TEXT NOT NULL,
    company_rnc TEXT UNIQUE NOT NULL,
    company_address TEXT,
    company_phone TEXT,
    company_email TEXT,
    fiscal_sequence INTEGER NOT NULL DEFAULT 0,
    governmental_sequence INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de clientes
CREATE TABLE public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    rnc_cedula TEXT UNIQUE,
    email TEXT,
    phone TEXT,
    address TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de productos
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    sku TEXT UNIQUE NOT NULL,
    description TEXT,
    cost DECIMAL(10, 2) NOT NULL DEFAULT 0,
    price DECIMAL(10, 2) NOT NULL DEFAULT 0,
    stock INTEGER NOT NULL DEFAULT 0,
    min_stock INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de órdenes
CREATE TABLE public.orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES public.customers(id) ON DELETE SET NULL,
    customer_name TEXT NOT NULL,
    customer_rnc TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    status order_status NOT NULL DEFAULT 'Pendiente',
    invoice_type invoice_type NOT NULL DEFAULT 'BASICA',
    
    -- Montos
    subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0,
    tax DECIMAL(10, 2) NOT NULL DEFAULT 0,
    discount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total DECIMAL(10, 2) NOT NULL DEFAULT 0,
    
    -- Pagos
    payment_status payment_status NOT NULL DEFAULT 'Pendiente',
    total_paid DECIMAL(10, 2) NOT NULL DEFAULT 0,
    pending_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    
    -- Asignación
    assigned_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ,
    
    -- Referencias
    invoice_id UUID, -- Se llena cuando se convierte a factura
    
    -- Metadatos
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de items de órdenes
CREATE TABLE public.order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_sku TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de pagos de órdenes
CREATE TABLE public.order_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    payment_method payment_method NOT NULL,
    payment_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de facturas
CREATE TABLE public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number TEXT UNIQUE NOT NULL,
    invoice_type invoice_type NOT NULL,
    ncf TEXT, -- Solo para facturas fiscales y gubernamentales
    
    -- Referencia a la orden
    order_id UUID REFERENCES public.orders(id) ON DELETE SET NULL,
    
    -- Datos del cliente
    customer_name TEXT NOT NULL,
    customer_rnc TEXT,
    customer_email TEXT,
    customer_phone TEXT,
    
    -- Montos
    subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0,
    tax DECIMAL(10, 2) NOT NULL DEFAULT 0,
    discount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total DECIMAL(10, 2) NOT NULL DEFAULT 0,
    
    -- Metadatos
    payment_method payment_method,
    notes TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de items de facturas
CREATE TABLE public.invoice_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    product_id UUID REFERENCES public.products(id) ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_sku TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10, 2) NOT NULL CHECK (unit_price >= 0),
    subtotal DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de movimientos de stock
CREATE TABLE public.stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    movement_type stock_movement_type NOT NULL,
    quantity INTEGER NOT NULL,
    reason TEXT,
    reference_id UUID, -- ID de orden, factura, etc.
    reference_type TEXT, -- 'order', 'invoice', 'adjustment'
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tabla de secuencias de facturas
CREATE TABLE public.invoice_sequences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_type invoice_type NOT NULL UNIQUE,
    current_sequence INTEGER NOT NULL DEFAULT 0,
    prefix TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- =====================================================
-- 4. CREAR ÍNDICES PARA RENDIMIENTO
-- =====================================================

-- Índices para órdenes
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_customer_id ON public.orders(customer_id);
CREATE INDEX idx_orders_assigned_to ON public.orders(assigned_to);
CREATE INDEX idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX idx_orders_invoice_id ON public.orders(invoice_id);
CREATE INDEX idx_orders_created_at ON public.orders(created_at DESC);

-- Índices para order_items
CREATE INDEX idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX idx_order_items_product_id ON public.order_items(product_id);

-- Índices para order_payments
CREATE INDEX idx_order_payments_order_id ON public.order_payments(order_id);
CREATE INDEX idx_order_payments_payment_date ON public.order_payments(payment_date DESC);

-- Índices para facturas
CREATE INDEX idx_invoices_invoice_type ON public.invoices(invoice_type);
CREATE INDEX idx_invoices_order_id ON public.invoices(order_id);
CREATE INDEX idx_invoices_created_at ON public.invoices(created_at DESC);

-- Índices para invoice_items
CREATE INDEX idx_invoice_items_invoice_id ON public.invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_product_id ON public.invoice_items(product_id);

-- Índices para productos
CREATE INDEX idx_products_sku ON public.products(sku);
CREATE INDEX idx_products_is_active ON public.products(is_active);
CREATE INDEX idx_products_stock ON public.products(stock);

-- Índices para clientes
CREATE INDEX idx_customers_rnc_cedula ON public.customers(rnc_cedula);
CREATE INDEX idx_customers_is_active ON public.customers(is_active);

-- Índices para movimientos de stock
CREATE INDEX idx_stock_movements_product_id ON public.stock_movements(product_id);
CREATE INDEX idx_stock_movements_created_at ON public.stock_movements(created_at DESC);
CREATE INDEX idx_stock_movements_reference ON public.stock_movements(reference_id, reference_type);

-- =====================================================
-- 5. CREAR FUNCIONES DE UTILIDAD
-- =====================================================

-- Función para actualizar updated_at
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Función para generar número de factura
CREATE OR REPLACE FUNCTION public.get_next_invoice_number(p_invoice_type invoice_type)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    next_seq INTEGER;
    prefix TEXT;
    invoice_num TEXT;
BEGIN
    -- Lock y incrementar secuencia
    UPDATE public.invoice_sequences
    SET current_sequence = current_sequence + 1,
        updated_at = NOW()
    WHERE invoice_type = p_invoice_type
    RETURNING current_sequence, prefix INTO next_seq, prefix;
    
    -- Formatear número según tipo
    IF p_invoice_type = 'BASICA' THEN
        invoice_num := prefix || '-' || LPAD(next_seq::TEXT, 6, '0');
    ELSE
        invoice_num := prefix || LPAD(next_seq::TEXT, 4, '0');
    END IF;
    
    RETURN invoice_num;
END;
$$;

-- Función para generar NCF
CREATE OR REPLACE FUNCTION public.generate_ncf(p_invoice_type invoice_type, p_sequence INTEGER)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    ncf TEXT;
BEGIN
    IF p_invoice_type = 'VALOR_FISCAL' THEN
        ncf := 'B0100000' || LPAD(p_sequence::TEXT, 4, '0');
    ELSIF p_invoice_type = 'VALOR_GUBERNAMENTAL' THEN
        ncf := 'B1500000' || LPAD(p_sequence::TEXT, 4, '0');
    ELSE
        ncf := NULL;
    END IF;
    
    RETURN ncf;
END;
$$;

-- Función para actualizar estado de pago de una orden
CREATE OR REPLACE FUNCTION public.update_order_payment_status(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    order_total DECIMAL(10, 2);
    total_paid DECIMAL(10, 2);
    pending_amount DECIMAL(10, 2);
    new_payment_status payment_status;
BEGIN
    -- Obtener total de la orden
    SELECT total INTO order_total
    FROM public.orders
    WHERE id = p_order_id;
    
    -- Obtener total pagado
    SELECT COALESCE(SUM(amount), 0) INTO total_paid
    FROM public.order_payments
    WHERE order_id = p_order_id;
    
    -- Calcular monto pendiente
    pending_amount := order_total - total_paid;
    
    -- Determinar estado de pago
    IF total_paid = 0 THEN
        new_payment_status := 'Pendiente';
    ELSIF pending_amount > 0 THEN
        new_payment_status := 'Parcial';
    ELSE
        new_payment_status := 'Completo';
    END IF;
    
    -- Actualizar orden
    UPDATE public.orders
    SET total_paid = total_paid,
        pending_amount = pending_amount,
        payment_status = new_payment_status,
        updated_at = NOW()
    WHERE id = p_order_id;
END;
$$;

-- Función para convertir orden a factura
CREATE OR REPLACE FUNCTION public.convert_order_to_invoice(
    p_order_id UUID,
    p_invoice_type invoice_type DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    order_record RECORD;
    invoice_id UUID;
    invoice_number TEXT;
    ncf TEXT;
    next_seq INTEGER;
    actual_invoice_type invoice_type;
BEGIN
    -- Obtener datos de la orden
    SELECT * INTO order_record
    FROM public.orders
    WHERE id = p_order_id;
    
    IF order_record IS NULL THEN
        RAISE EXCEPTION 'Order not found: %', p_order_id;
    END IF;
    
    -- Verificar que la orden esté completada
    IF order_record.status != 'Completada' THEN
        RAISE EXCEPTION 'Order must be completed before converting to invoice';
    END IF;
    
    -- Verificar que no esté ya convertida
    IF order_record.invoice_id IS NOT NULL THEN
        RAISE EXCEPTION 'Order already converted to invoice: %', order_record.invoice_id;
    END IF;
    
    -- Usar tipo de factura de la orden o el proporcionado
    actual_invoice_type := COALESCE(p_invoice_type, order_record.invoice_type);
    
    -- Generar número de factura
    SELECT public.get_next_invoice_number(actual_invoice_type) INTO invoice_number;
    
    -- Generar NCF si es necesario
    IF actual_invoice_type IN ('VALOR_FISCAL', 'VALOR_GUBERNAMENTAL') THEN
        next_seq := CAST(SUBSTRING(invoice_number FROM '[0-9]+$') AS INTEGER);
        SELECT public.generate_ncf(actual_invoice_type, next_seq) INTO ncf;
    END IF;
    
    -- Crear factura
    INSERT INTO public.invoices (
        invoice_number,
        invoice_type,
        ncf,
        order_id,
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
        actual_invoice_type,
        ncf,
        p_order_id,
        order_record.customer_name,
        order_record.customer_rnc,
        order_record.customer_email,
        order_record.customer_phone,
        order_record.subtotal,
        CASE 
            WHEN actual_invoice_type = 'BASICA' THEN 0
            ELSE order_record.tax
        END,
        order_record.discount,
        CASE 
            WHEN actual_invoice_type = 'BASICA' THEN order_record.subtotal
            ELSE order_record.total
        END,
        'Efectivo', -- Método por defecto
        order_record.notes,
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
    SET invoice_id = invoice_id,
        status = 'Facturada',
        updated_at = NOW()
    WHERE id = p_order_id;
    
    RETURN invoice_id;
END;
$$;

-- Función para actualizar stock de producto
CREATE OR REPLACE FUNCTION public.update_product_stock(
    p_product_id UUID,
    p_quantity INTEGER,
    p_movement_type stock_movement_type,
    p_reason TEXT DEFAULT NULL,
    p_reference_id UUID DEFAULT NULL,
    p_reference_type TEXT DEFAULT NULL,
    p_user_id UUID DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    current_stock INTEGER;
    new_stock INTEGER;
    quantity_change INTEGER;
BEGIN
    -- Obtener stock actual
    SELECT stock INTO current_stock
    FROM public.products
    WHERE id = p_product_id;
    
    IF current_stock IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Product not found');
    END IF;
    
    -- Calcular cambio de cantidad
    IF p_movement_type = 'ENTRADA' THEN
        quantity_change := p_quantity;
    ELSE
        quantity_change := -p_quantity;
    END IF;
    
    new_stock := current_stock + quantity_change;
    
    -- Verificar stock negativo
    IF new_stock < 0 THEN
        RETURN json_build_object(
            'success', false, 
            'error', 'Insufficient stock', 
            'current_stock', current_stock, 
            'requested', p_quantity
        );
    END IF;
    
    -- Actualizar stock
    UPDATE public.products
    SET stock = new_stock,
        updated_at = NOW()
    WHERE id = p_product_id;
    
    -- Registrar movimiento
    INSERT INTO public.stock_movements (
        product_id,
        movement_type,
        quantity,
        reason,
        reference_id,
        reference_type,
        created_by
    ) VALUES (
        p_product_id,
        p_movement_type,
        p_quantity,
        p_reason,
        p_reference_id,
        p_reference_type,
        p_user_id
    );
    
    RETURN json_build_object(
        'success', true, 
        'old_stock', current_stock, 
        'new_stock', new_stock
    );
END;
$$;

-- =====================================================
-- 6. CREAR TRIGGERS
-- =====================================================

-- Trigger para actualizar updated_at en profiles
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger para actualizar updated_at en business_config
CREATE TRIGGER update_business_config_updated_at
    BEFORE UPDATE ON public.business_config
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger para actualizar updated_at en customers
CREATE TRIGGER update_customers_updated_at
    BEFORE UPDATE ON public.customers
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger para actualizar updated_at en products
CREATE TRIGGER update_products_updated_at
    BEFORE UPDATE ON public.products
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger para actualizar updated_at en orders
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger para actualizar updated_at en invoice_sequences
CREATE TRIGGER update_invoice_sequences_updated_at
    BEFORE UPDATE ON public.invoice_sequences
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at();

-- Trigger para actualizar estado de pago cuando se agrega un pago
CREATE OR REPLACE FUNCTION public.trigger_update_payment_status()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.update_order_payment_status(NEW.order_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_payment_status_after_payment
    AFTER INSERT OR UPDATE OR DELETE ON public.order_payments
    FOR EACH ROW
    EXECUTE FUNCTION public.trigger_update_payment_status();

-- =====================================================
-- 7. INSERTAR DATOS INICIALES
-- =====================================================

-- Insertar usuario admin por defecto
INSERT INTO public.profiles (id, email, full_name, role) VALUES
(gen_random_uuid(), 'admin@empresa.com', 'Administrador', 'Admin')
ON CONFLICT (email) DO NOTHING;

-- Insertar configuración de negocio por defecto
INSERT INTO public.business_config (
    company_name,
    company_rnc,
    fiscal_sequence,
    governmental_sequence
) VALUES (
    'Mi Empresa',
    '123456789',
    0,
    0
) ON CONFLICT DO NOTHING;

-- Insertar secuencias de facturas
INSERT INTO public.invoice_sequences (invoice_type, current_sequence, prefix) VALUES
('BASICA', 0, 'BAS'),
('VALOR_FISCAL', 0, 'B0100000'),
('VALOR_GUBERNAMENTAL', 0, 'B1500000')
ON CONFLICT (invoice_type) DO NOTHING;

-- =====================================================
-- 8. VERIFICACIÓN FINAL
-- =====================================================

-- Mostrar resumen de tablas creadas
SELECT 
    'Tablas creadas:' as info,
    COUNT(*) as total
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE';

-- Mostrar resumen de funciones creadas
SELECT 
    'Funciones creadas:' as info,
    COUNT(*) as total
FROM information_schema.routines 
WHERE routine_schema = 'public';

-- Mostrar resumen de tipos creados
SELECT 
    'Tipos creados:' as info,
    COUNT(*) as total
FROM pg_type 
WHERE typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
AND typtype = 'e';

SELECT 'Base de datos creada exitosamente. Sistema listo para producción.' as result;
