-- Insert default business configuration
INSERT INTO public.business_config (
  business_name,
  rnc,
  address,
  phone,
  email,
  low_stock_threshold
) VALUES (
  'Mi Empresa',
  '000-0000000-0',
  'Calle Principal #123, Santo Domingo',
  '809-000-0000',
  'info@miempresa.com',
  10
)
ON CONFLICT DO NOTHING;

-- Insert sample products
INSERT INTO public.products (name, description, sku, price, cost, stock, min_stock, category, is_active) VALUES
  ('Laptop Dell Inspiron 15', 'Laptop 15 pulgadas, Intel i5, 8GB RAM, 256GB SSD', 'LAP-001', 45000.00, 35000.00, 15, 5, 'Computadoras', true),
  ('Mouse Logitech M185', 'Mouse inalámbrico, 2.4GHz', 'MOU-001', 450.00, 300.00, 50, 10, 'Accesorios', true),
  ('Teclado Mecánico RGB', 'Teclado mecánico con iluminación RGB', 'TEC-001', 2500.00, 1800.00, 25, 8, 'Accesorios', true),
  ('Monitor Samsung 24"', 'Monitor Full HD 24 pulgadas', 'MON-001', 8500.00, 6500.00, 12, 5, 'Monitores', true),
  ('Impresora HP LaserJet', 'Impresora láser monocromática', 'IMP-001', 12000.00, 9000.00, 8, 3, 'Impresoras', true),
  ('Cable HDMI 2m', 'Cable HDMI 2.0, 2 metros', 'CAB-001', 350.00, 200.00, 100, 20, 'Cables', true),
  ('Disco Duro Externo 1TB', 'Disco duro externo USB 3.0, 1TB', 'HDD-001', 2800.00, 2000.00, 30, 10, 'Almacenamiento', true),
  ('Memoria USB 32GB', 'Memoria USB 3.0, 32GB', 'USB-001', 450.00, 300.00, 80, 20, 'Almacenamiento', true),
  ('Webcam Logitech C920', 'Webcam Full HD 1080p', 'WEB-001', 3500.00, 2500.00, 18, 5, 'Accesorios', true),
  ('Audífonos Bluetooth', 'Audífonos inalámbricos con cancelación de ruido', 'AUD-001', 1800.00, 1200.00, 35, 10, 'Audio', true)
ON CONFLICT (sku) DO NOTHING;

-- Insert sample customers
INSERT INTO public.customers (name, rnc_cedula, email, phone, address) VALUES
  ('Juan Pérez', '001-0123456-7', 'juan.perez@email.com', '809-111-1111', 'Av. Winston Churchill, Santo Domingo'),
  ('María García', '001-0234567-8', 'maria.garcia@email.com', '809-222-2222', 'Calle El Conde, Zona Colonial'),
  ('Empresa ABC, SRL', '101-12345-6', 'contacto@empresaabc.com', '809-333-3333', 'Av. 27 de Febrero, Santo Domingo'),
  ('Pedro Martínez', '001-0345678-9', 'pedro.martinez@email.com', '809-444-4444', 'Av. Independencia, Santo Domingo'),
  ('Comercial XYZ', '101-23456-7', 'ventas@comercialxyz.com', '809-555-5555', 'Av. Abraham Lincoln, Santo Domingo')
ON CONFLICT DO NOTHING;
