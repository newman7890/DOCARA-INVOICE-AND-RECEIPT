-- DOCARA POS - DATABASE OPTIMIZATION SCRIPT
-- Run this in your Supabase SQL Editor to enable high-traffic features.

-- 1. Optimized Indexes
-- These make searching and filtering through thousands of records instant.
CREATE INDEX IF NOT EXISTS idx_invoices_business_id ON invoices(business_id);
CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(date DESC);
CREATE INDEX IF NOT EXISTS idx_invoices_client_name ON invoices(client_name);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON products(business_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products(barcode);
CREATE INDEX IF NOT EXISTS idx_customers_business_id ON customers(business_id);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name);
CREATE INDEX IF NOT EXISTS idx_staff_business_id ON staff(business_id);

-- 2. Atomic Stock Management
-- Handles high-concurrency stock reductions without data loss.
CREATE OR REPLACE FUNCTION decrement_product_stock(p_id TEXT, p_quantity INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE products
  SET stock_quantity = stock_quantity - p_quantity
  WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

-- 3. Atomic Customer Statistics
-- Ensures customer spending and visit counts are calculated correctly 
-- even if multiple cashiers sell to the same customer at once.
CREATE OR REPLACE FUNCTION increment_customer_stats(c_id TEXT, p_amount NUMERIC, p_count INTEGER)
RETURNS VOID AS $$
BEGIN
  UPDATE customers
  SET total_spent = COALESCE(total_spent, 0) + p_amount,
      invoice_count = COALESCE(invoice_count, 0) + p_count
  WHERE id = c_id;
END;
$$ LANGUAGE plpgsql;
