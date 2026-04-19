-- Migration: add fields for print system
-- Run in: Supabase Dashboard → SQL Editor

-- 1. Customer address
ALTER TABLE customers ADD COLUMN IF NOT EXISTS address TEXT;

-- 2. Invoice allocation number (max 20 chars)
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS allocnum VARCHAR(20);

-- 3. Company tax authority constant
ALTER TABLE company ADD COLUMN IF NOT EXISTS taxconst NUMERIC;

-- 4. Reload schema cache
NOTIFY pgrst, 'reload schema';
