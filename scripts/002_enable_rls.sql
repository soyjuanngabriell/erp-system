-- Enable Row Level Security on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.business_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_counter ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles"
  ON public.profiles FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Admins can insert profiles"
  ON public.profiles FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

CREATE POLICY "Admins can delete profiles"
  ON public.profiles FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Business config policies (Admin only)
CREATE POLICY "Anyone can view business config"
  ON public.business_config FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage business config"
  ON public.business_config FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Products policies
CREATE POLICY "Anyone can view active products"
  ON public.products FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage products"
  ON public.products FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Customers policies
CREATE POLICY "Anyone can view customers"
  ON public.customers FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Anyone can create customers"
  ON public.customers FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can update customers"
  ON public.customers FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

CREATE POLICY "Admins can delete customers"
  ON public.customers FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Orders policies
CREATE POLICY "Users can view all orders"
  ON public.orders FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can create orders"
  ON public.orders FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update own orders or admins can update any"
  ON public.orders FOR UPDATE
  USING (
    created_by = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

CREATE POLICY "Admins can delete orders"
  ON public.orders FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Order items policies
CREATE POLICY "Users can view order items"
  ON public.order_items FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can create order items"
  ON public.order_items FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update order items"
  ON public.order_items FOR UPDATE
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can delete order items"
  ON public.order_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Invoices policies
CREATE POLICY "Users can view all invoices"
  ON public.invoices FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can create invoices"
  ON public.invoices FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can update invoices"
  ON public.invoices FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

CREATE POLICY "Admins can delete invoices"
  ON public.invoices FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Invoice items policies
CREATE POLICY "Users can view invoice items"
  ON public.invoice_items FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can create invoice items"
  ON public.invoice_items FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage invoice items"
  ON public.invoice_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Stock movements policies
CREATE POLICY "Users can view stock movements"
  ON public.stock_movements FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage stock movements"
  ON public.stock_movements FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'Admin'
    )
  );

-- Invoice counter policies
CREATE POLICY "Users can view invoice counter"
  ON public.invoice_counter FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update invoice counter"
  ON public.invoice_counter FOR UPDATE
  USING (auth.uid() IS NOT NULL);
