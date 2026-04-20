-- Add print_config JSON column to company table
ALTER TABLE company ADD COLUMN IF NOT EXISTS print_config JSONB;
