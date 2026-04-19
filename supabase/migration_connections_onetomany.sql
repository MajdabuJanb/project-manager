-- Migration: client_connections → one-to-many
-- Remove UNIQUE constraint on custid, add connname column
-- Run in: Supabase Dashboard → SQL Editor

-- Add connname column (if not exists)
ALTER TABLE client_connections ADD COLUMN IF NOT EXISTS connname TEXT;

-- Drop the unique constraint that limited to one connection per customer
ALTER TABLE client_connections DROP CONSTRAINT IF EXISTS client_connections_custid_key;

-- Add RLS policy (if missing)
ALTER TABLE client_connections ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "connections_admin" ON client_connections;
CREATE POLICY "connections_admin" ON client_connections FOR ALL USING (is_admin());
