-- Migration: fix missing columns + reload PostgREST schema cache
-- Run in: Supabase Dashboard → SQL Editor

-- 1. Ensure custid exists in client_connections (was in original schema but may be missing)
ALTER TABLE client_connections ADD COLUMN IF NOT EXISTS custid UUID REFERENCES customers(custid) ON DELETE CASCADE;

-- 2. Ensure vatrate exists in company
ALTER TABLE company ADD COLUMN IF NOT EXISTS vatrate DECIMAL(5,2) DEFAULT 17;

-- 3. Reload PostgREST schema cache (fixes "column not found in schema cache" errors)
NOTIFY pgrst, 'reload schema';
