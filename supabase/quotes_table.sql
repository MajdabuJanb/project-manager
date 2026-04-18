-- ============================================================
-- QUOTES + QUOTE_LINES TABLES
-- Run in Supabase SQL Editor
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS quote_num_seq START 1;

CREATE TABLE IF NOT EXISTS quotes (
  quoteid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  custid    UUID NOT NULL REFERENCES customers(custid) ON DELETE RESTRICT,
  quotenum  TEXT UNIQUE,
  qdate     DATE,
  validdate DATE,
  ponum     TEXT,
  status    TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','sent','approved','rejected','cancelled')),
  vatrate   DECIMAL(5,2) DEFAULT 17,
  subtotal  DECIMAL(14,2) DEFAULT 0,
  vatamt    DECIMAL(14,2) DEFAULT 0,
  total     DECIMAL(14,2) DEFAULT 0,
  notes     TEXT,
  cdate     TIMESTAMPTZ DEFAULT NOW(),
  udate     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS quote_lines (
  lineid    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  quoteid   UUID NOT NULL REFERENCES quotes(quoteid) ON DELETE CASCADE,
  linenum   INTEGER NOT NULL DEFAULT 1,
  partid    TEXT REFERENCES parts(partid) ON DELETE SET NULL,
  linedes   TEXT,
  qty       DECIMAL(12,4) DEFAULT 1,
  unitprice DECIMAL(14,2) DEFAULT 0,
  discount  DECIMAL(5,2)  DEFAULT 0,
  linetotal DECIMAL(14,2) DEFAULT 0,
  cdate     TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-number trigger: QT260001
CREATE OR REPLACE FUNCTION gen_quote_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.quotenum IS NULL THEN
    NEW.quotenum := 'QT' || TO_CHAR(NOW(), 'YY') ||
                   LPAD(nextval('quote_num_seq')::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_quote_number ON quotes;
CREATE TRIGGER trg_quote_number BEFORE INSERT ON quotes
  FOR EACH ROW EXECUTE FUNCTION gen_quote_number();

-- udate trigger
CREATE TRIGGER quotes_udate BEFORE UPDATE ON quotes
  FOR EACH ROW EXECUTE FUNCTION update_udate();

-- RLS
ALTER TABLE quotes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE quote_lines ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "quotes_admin"      ON quotes;
CREATE POLICY "quotes_admin"      ON quotes      FOR ALL USING (is_admin());
DROP POLICY IF EXISTS "quote_lines_admin" ON quote_lines;
CREATE POLICY "quote_lines_admin" ON quote_lines FOR ALL USING (is_admin());

-- Index
CREATE INDEX IF NOT EXISTS idx_quotes_custid   ON quotes(custid);
CREATE INDEX IF NOT EXISTS idx_qlines_quoteid  ON quote_lines(quoteid);
