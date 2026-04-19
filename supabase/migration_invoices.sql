-- ============================================================
-- Migration: Invoices entity + client_connections fix
-- Run in: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Fix client_connections: rename client_id → custid (if column is named client_id)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'client_connections' AND column_name = 'client_id'
  ) THEN
    ALTER TABLE client_connections RENAME COLUMN client_id TO custid;
  END IF;
END $$;

-- 2. Add invoiced flag to quotes
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS invoiced BOOLEAN DEFAULT false;

-- 3. Invoice sequences
CREATE SEQUENCE IF NOT EXISTS inv_temp_seq  START 1;
CREATE SEQUENCE IF NOT EXISTS inv_final_seq START 1;

-- 4. Invoices table
CREATE TABLE IF NOT EXISTS invoices (
  invid       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invtempnum  TEXT,
  invfinalnum TEXT,
  invnum      TEXT,
  status      TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','final','cancelled')),
  idate       DATE NOT NULL DEFAULT CURRENT_DATE,
  custid      UUID NOT NULL REFERENCES customers(custid) ON DELETE RESTRICT,
  quoteid     UUID REFERENCES quotes(quoteid) ON DELETE SET NULL,
  vatrate     DECIMAL(5,2) DEFAULT 17,
  subtotal    DECIMAL(14,2) DEFAULT 0,
  vatamt      DECIMAL(14,2) DEFAULT 0,
  total       DECIMAL(14,2) DEFAULT 0,
  notes       TEXT,
  printed     BOOLEAN DEFAULT false,
  cdate       TIMESTAMPTZ DEFAULT NOW(),
  udate       TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Invoice lines table
CREATE TABLE IF NOT EXISTS invoice_lines (
  ilineid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invid     UUID NOT NULL REFERENCES invoices(invid) ON DELETE CASCADE,
  linenum   INTEGER NOT NULL DEFAULT 1,
  linedes   TEXT,
  qty       DECIMAL(12,4) DEFAULT 1,
  unitprice DECIMAL(14,2) DEFAULT 0,
  discount  DECIMAL(5,2)  DEFAULT 0,
  linetotal DECIMAL(14,2) DEFAULT 0,
  cdate     TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Auto-assign temp number on insert
CREATE OR REPLACE FUNCTION gen_inv_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.invtempnum IS NULL THEN
    NEW.invtempnum := 'T' || TO_CHAR(NOW(), 'YY') || LPAD(nextval('inv_temp_seq')::TEXT, 4, '0');
    NEW.invnum     := NEW.invtempnum;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_inv_number ON invoices;
CREATE TRIGGER trg_inv_number BEFORE INSERT ON invoices
  FOR EACH ROW EXECUTE FUNCTION gen_inv_number();

-- 7. close_invoice RPC — assigns final number, locks invoice
CREATE OR REPLACE FUNCTION close_invoice(p_invid UUID)
RETURNS TEXT AS $$
DECLARE
  v_finalnum TEXT;
  v_status   TEXT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT status INTO v_status FROM invoices WHERE invid = p_invid;
  IF v_status IS NULL THEN RAISE EXCEPTION 'חשבונית לא נמצאה'; END IF;
  IF v_status <> 'draft' THEN RAISE EXCEPTION 'ניתן לסגור רק חשבוניות בסטטוס טיוטה'; END IF;
  v_finalnum := 'INV' || TO_CHAR(NOW(), 'YY') || LPAD(nextval('inv_final_seq')::TEXT, 4, '0');
  UPDATE invoices
  SET status = 'final', invfinalnum = v_finalnum, invnum = v_finalnum, udate = NOW()
  WHERE invid = p_invid;
  RETURN v_finalnum;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION close_invoice(UUID) TO authenticated;

-- 8. void_invoice RPC — cancels invoice, releases linked quote
CREATE OR REPLACE FUNCTION void_invoice(p_invid UUID)
RETURNS void AS $$
DECLARE
  v_quoteid UUID;
  v_status  TEXT;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  SELECT status, quoteid INTO v_status, v_quoteid FROM invoices WHERE invid = p_invid;
  IF v_status IS NULL THEN RAISE EXCEPTION 'חשבונית לא נמצאה'; END IF;
  IF v_status = 'cancelled' THEN RAISE EXCEPTION 'החשבונית כבר מבוטלת'; END IF;
  UPDATE invoices SET status = 'cancelled', udate = NOW() WHERE invid = p_invid;
  IF v_quoteid IS NOT NULL THEN
    UPDATE quotes SET invoiced = false WHERE quoteid = v_quoteid;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION void_invoice(UUID) TO authenticated;

-- 9. Indexes
CREATE INDEX IF NOT EXISTS idx_invoices_custid  ON invoices(custid);
CREATE INDEX IF NOT EXISTS idx_invoices_quoteid ON invoices(quoteid);
CREATE INDEX IF NOT EXISTS idx_invoice_lines_invid ON invoice_lines(invid);

-- 10. RLS
ALTER TABLE invoices      ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_lines ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "invoices_admin"      ON invoices;
CREATE POLICY "invoices_admin"      ON invoices      FOR ALL USING (is_admin());
DROP POLICY IF EXISTS "invoice_lines_admin" ON invoice_lines;
CREATE POLICY "invoice_lines_admin" ON invoice_lines FOR ALL USING (is_admin());

-- 11. udate trigger for invoices
DROP TRIGGER IF EXISTS invoices_udate ON invoices;
CREATE TRIGGER invoices_udate BEFORE UPDATE ON invoices
  FOR EACH ROW EXECUTE FUNCTION update_udate();

-- 12. Update go_live() to reset invoice sequences
CREATE OR REPLACE FUNCTION go_live()
RETURNS void AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Unauthorized'; END IF;
  DELETE FROM activity_log;
  DELETE FROM customers;
  DELETE FROM parts;
  UPDATE company SET isdemo = false;
  EXECUTE 'ALTER SEQUENCE client_num_seq  RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE project_num_seq RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE task_num_seq    RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE part_num_seq    RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE quote_num_seq   RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE inv_temp_seq    RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE inv_final_seq   RESTART WITH 1';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Reload schema cache
NOTIFY pgrst, 'reload schema';
