-- DOCARA POS - CRITICAL DATABASE FIXES
-- Run this in your Supabase SQL Editor to fix app crashes and missing data issues.

-- 1. Fix 'businesses' table schema
-- Adding missing columns that the app expects.
ALTER TABLE businesses 
ADD COLUMN IF NOT EXISTS logo_url TEXT,
ADD COLUMN IF NOT EXISTS signature_url TEXT,
ADD COLUMN IF NOT EXISTS revenue_goal NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT '₵',
ADD COLUMN IF NOT EXISTS email TEXT,
ADD COLUMN IF NOT EXISTS phone TEXT,
ADD COLUMN IF NOT EXISTS address TEXT;

-- 2. Create 'app_metadata' table (For In-App Updates)
-- This powers the auto-update prompt feature.
DROP TABLE IF EXISTS public.app_metadata; -- Drop incorrect schema if it exists

CREATE TABLE public.app_metadata (
    id BIGSERIAL PRIMARY KEY,
    key TEXT UNIQUE NOT NULL,
    value TEXT NOT NULL,
    download_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert the current version as the latest version
INSERT INTO public.app_metadata (key, value, download_url) 
VALUES (
    'latest_version', 
    '1.1.0+2', 
    'https://your-website.com/download/app-release.apk'
)
ON CONFLICT (key) DO UPDATE 
SET value = EXCLUDED.value, download_url = EXCLUDED.download_url;

-- 3. Ensure 'customers' table has correct stats columns
ALTER TABLE customers
ADD COLUMN IF NOT EXISTS total_spent NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS invoice_count INTEGER DEFAULT 0;
