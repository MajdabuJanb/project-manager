-- Migration: add ITA (Israel Tax Authority) API fields to company
-- Run in: Supabase Dashboard → SQL Editor

ALTER TABLE company ADD COLUMN IF NOT EXISTS ita_token TEXT;
ALTER TABLE company ADD COLUMN IF NOT EXISTS ita_sandbox BOOLEAN DEFAULT true;

-- Reload schema cache
NOTIFY pgrst, 'reload schema';
