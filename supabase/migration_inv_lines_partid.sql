-- Migration: add partid to invoice_lines
-- Run in: Supabase Dashboard → SQL Editor

ALTER TABLE invoice_lines
  ADD COLUMN IF NOT EXISTS partid TEXT REFERENCES parts(partid) ON DELETE SET NULL;

NOTIFY pgrst, 'reload schema';
