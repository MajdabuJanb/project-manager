-- Rename priority_username/priority_password → erp_username/erp_password
-- Run once in Supabase SQL editor

ALTER TABLE client_connections
  RENAME COLUMN priority_username TO erp_username;

ALTER TABLE client_connections
  RENAME COLUMN priority_password TO erp_password;
