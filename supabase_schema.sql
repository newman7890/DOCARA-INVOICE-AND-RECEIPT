-- =============================================
-- DOCARA POS - SUPABASE SCHEMA
-- Run this entire script in the SQL Editor
-- =============================================

-- Businesses (one per SaaS customer)
CREATE TABLE IF NOT EXISTS businesses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  currency TEXT DEFAULT '₵',
  email TEXT,
  phone TEXT,
  address TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Staff / Cashiers
CREATE TABLE IF NOT EXISTS staff (
  id TEXT PRIMARY KEY,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  role TEXT DEFAULT 'Cashier',
  phone TEXT,
  pin TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Products / Inventory
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  price NUMERIC NOT NULL DEFAULT 0,
  cost_price NUMERIC,
  description TEXT,
  barcode TEXT,
  stock_quantity INT DEFAULT 0,
  min_stock_level INT DEFAULT 5,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Customers
CREATE TABLE IF NOT EXISTS customers (
  id TEXT PRIMARY KEY,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  address TEXT DEFAULT '',
  contact TEXT DEFAULT '',
  total_spent NUMERIC DEFAULT 0,
  invoice_count INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invoices
CREATE TABLE IF NOT EXISTS invoices (
  id TEXT PRIMARY KEY,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  due_date TIMESTAMPTZ,
  type TEXT NOT NULL DEFAULT 'invoice',
  client_name TEXT DEFAULT '',
  client_address TEXT DEFAULT '',
  client_contact TEXT DEFAULT '',
  discount_value NUMERIC DEFAULT 0,
  discount_type TEXT DEFAULT 'fixed',
  tax_value NUMERIC DEFAULT 0,
  amount_paid NUMERIC DEFAULT 0,
  payment_method TEXT DEFAULT 'cash',
  is_estimate BOOLEAN DEFAULT FALSE,
  is_pos BOOLEAN DEFAULT FALSE,
  cashier_name TEXT,
  station_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Invoice Line Items
CREATE TABLE IF NOT EXISTS invoice_items (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  invoice_id TEXT REFERENCES invoices(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  quantity INT NOT NULL DEFAULT 1,
  selling_price NUMERIC NOT NULL DEFAULT 0,
  cost_price NUMERIC
);

-- Expenses
CREATE TABLE IF NOT EXISTS expenses (
  id TEXT PRIMARY KEY,
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  description TEXT DEFAULT '',
  category TEXT DEFAULT 'other',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =============================================
-- ROW LEVEL SECURITY (data isolation)
-- =============================================

ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;

-- Businesses: owner only
CREATE POLICY "Owner can manage their business" ON businesses
  FOR ALL USING (owner_id = auth.uid());

-- Helper: get the business ID for the logged-in user
CREATE OR REPLACE FUNCTION get_my_business_id()
RETURNS UUID AS $$
  SELECT id FROM businesses WHERE owner_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER;

-- Staff policies
CREATE POLICY "Business owner manages staff" ON staff
  FOR ALL USING (business_id = get_my_business_id());

-- Products policies
CREATE POLICY "Business owner manages products" ON products
  FOR ALL USING (business_id = get_my_business_id());

-- Customers policies
CREATE POLICY "Business owner manages customers" ON customers
  FOR ALL USING (business_id = get_my_business_id());

-- Invoices policies
CREATE POLICY "Business owner manages invoices" ON invoices
  FOR ALL USING (business_id = get_my_business_id());

-- Invoice items policies
CREATE POLICY "Business owner manages invoice items" ON invoice_items
  FOR ALL USING (
    invoice_id IN (
      SELECT id FROM invoices WHERE business_id = get_my_business_id()
    )
  );

-- Expenses policies
CREATE POLICY "Business owner manages expenses" ON expenses
  FOR ALL USING (business_id = get_my_business_id());

-- =============================================
-- REALTIME (enable real-time for admin dashboard)
-- =============================================
ALTER PUBLICATION supabase_realtime ADD TABLE invoices;
ALTER PUBLICATION supabase_realtime ADD TABLE invoice_items;
