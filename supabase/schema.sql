-- ============================================================
-- PROJECT MANAGER - Supabase Schema + RLS
-- Naming convention: no underscores, PKs include table name
-- Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id      UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  role    TEXT NOT NULL DEFAULT 'client' CHECK (role IN ('admin', 'client')),
  cdate   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS customers (
  custid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  custname TEXT NOT NULL,
  email    TEXT NOT NULL,
  phone    TEXT,
  custcomp TEXT,
  notes    TEXT,
  status   TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  token    UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
  custnum  TEXT UNIQUE,
  odate    DATE NOT NULL DEFAULT CURRENT_DATE,
  cdate    TIMESTAMPTZ DEFAULT NOW(),
  udate    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  projid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  custid   UUID NOT NULL REFERENCES customers(custid) ON DELETE CASCADE,
  projname TEXT NOT NULL,
  projdes  TEXT,
  status   TEXT NOT NULL DEFAULT 'planning'
    CHECK (status IN ('planning', 'active', 'paused', 'completed', 'cancelled')),
  priority TEXT DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  sdate    DATE,
  edate    DATE,
  budget   DECIMAL(12,2),
  hours    DECIMAL(10,2),
  progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  projnum  TEXT UNIQUE,
  odate    DATE NOT NULL DEFAULT CURRENT_DATE,
  cdate    TIMESTAMPTZ DEFAULT NOW(),
  udate    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tasks (
  taskid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  projid   UUID NOT NULL REFERENCES projects(projid) ON DELETE CASCADE,
  taskname TEXT NOT NULL,
  taskdes  TEXT,
  status   TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'completed', 'blocked')),
  priority TEXT DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  duedate  DATE,
  assignto TEXT,
  tasknum  TEXT UNIQUE,
  odate    DATE NOT NULL DEFAULT CURRENT_DATE,
  cdate    TIMESTAMPTZ DEFAULT NOW(),
  udate    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS parts (
  partid   TEXT PRIMARY KEY,
  partname TEXT UNIQUE NOT NULL,
  partdes  TEXT,
  cdate    TIMESTAMPTZ DEFAULT NOW(),
  udate    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS company (
  compid   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  compname TEXT,
  ownname  TEXT,
  taxnum   TEXT,
  phone    TEXT,
  email    TEXT,
  website  TEXT,
  addr1    TEXT,
  addr2    TEXT,
  city     TEXT,
  zip      TEXT,
  bankdet  TEXT,
  logo     TEXT,
  vatrate  DECIMAL(5,2) DEFAULT 17,
  isdemo   BOOLEAN DEFAULT true,
  udate    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS statuses (
  statusid  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity    TEXT NOT NULL CHECK (entity IN ('project', 'task', 'customer')),
  statuskey TEXT NOT NULL,
  label     TEXT NOT NULL,
  color     TEXT DEFAULT '#94a3b8',
  isdefault BOOLEAN DEFAULT false,
  sortorder INTEGER DEFAULT 0,
  UNIQUE (entity, statuskey)
);

CREATE TABLE IF NOT EXISTS activity_log (
  logid  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  etype  TEXT NOT NULL CHECK (etype IN ('client', 'project', 'task', 'part')),
  eid    UUID NOT NULL,
  ename  TEXT,
  action TEXT NOT NULL,
  details JSONB DEFAULT '{}',
  cdate  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_projects_custid   ON projects(custid);
CREATE INDEX IF NOT EXISTS idx_tasks_projid      ON tasks(projid);
CREATE INDEX IF NOT EXISTS idx_actlog_cdate      ON activity_log(cdate DESC);
CREATE INDEX IF NOT EXISTS idx_customers_token   ON customers(token);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles     ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers    ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE parts        ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

DROP POLICY IF EXISTS "profiles_select"    ON profiles;
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (id = auth.uid() OR is_admin());

DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "customers_admin"    ON customers;
CREATE POLICY "customers_admin" ON customers FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "projects_admin"     ON projects;
CREATE POLICY "projects_admin" ON projects FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "tasks_admin"        ON tasks;
CREATE POLICY "tasks_admin" ON tasks FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "parts_admin"        ON parts;
CREATE POLICY "parts_admin" ON parts FOR ALL USING (is_admin());

ALTER TABLE statuses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "statuses_admin" ON statuses;
CREATE POLICY "statuses_admin" ON statuses FOR ALL USING (is_admin());
DROP POLICY IF EXISTS "statuses_read"  ON statuses;
CREATE POLICY "statuses_read"  ON statuses FOR SELECT USING (true);

DROP POLICY IF EXISTS "activity_admin"     ON activity_log;
CREATE POLICY "activity_admin" ON activity_log FOR ALL USING (is_admin());

-- ============================================================
-- TRIGGERS — udate + new user profile
-- ============================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, role)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'role', 'client'))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

CREATE OR REPLACE FUNCTION update_udate()
RETURNS TRIGGER AS $$
BEGIN NEW.udate = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER customers_udate BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_udate();
CREATE TRIGGER projects_udate  BEFORE UPDATE ON projects  FOR EACH ROW EXECUTE FUNCTION update_udate();
CREATE TRIGGER tasks_udate     BEFORE UPDATE ON tasks     FOR EACH ROW EXECUTE FUNCTION update_udate();
CREATE TRIGGER parts_udate     BEFORE UPDATE ON parts     FOR EACH ROW EXECUTE FUNCTION update_udate();

-- ============================================================
-- SEQUENTIAL NUMBERS
-- ============================================================

CREATE SEQUENCE IF NOT EXISTS client_num_seq  START 1;
CREATE SEQUENCE IF NOT EXISTS project_num_seq START 1;
CREATE SEQUENCE IF NOT EXISTS task_num_seq    START 1;
CREATE SEQUENCE IF NOT EXISTS part_num_seq    START 1;

CREATE OR REPLACE FUNCTION gen_client_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.custnum IS NULL THEN
    NEW.custnum := 'C' || LPAD(nextval('client_num_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gen_project_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.projnum IS NULL THEN
    NEW.projnum := 'P' || LPAD(nextval('project_num_seq')::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gen_task_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tasknum IS NULL THEN
    NEW.tasknum := 'M' || LPAD(nextval('task_num_seq')::TEXT, 6, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gen_part_number()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.partid IS NULL OR NEW.partid = '' THEN
    NEW.partid := 'PR' || LPAD(nextval('part_num_seq')::TEXT, 5, '0');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_client_number  ON customers;
CREATE TRIGGER trg_client_number  BEFORE INSERT ON customers
  FOR EACH ROW EXECUTE FUNCTION gen_client_number();

DROP TRIGGER IF EXISTS trg_project_number ON projects;
CREATE TRIGGER trg_project_number BEFORE INSERT ON projects
  FOR EACH ROW EXECUTE FUNCTION gen_project_number();

DROP TRIGGER IF EXISTS trg_task_number ON tasks;
CREATE TRIGGER trg_task_number BEFORE INSERT ON tasks
  FOR EACH ROW EXECUTE FUNCTION gen_task_number();

DROP TRIGGER IF EXISTS trg_part_number ON parts;
CREATE TRIGGER trg_part_number BEFORE INSERT ON parts
  FOR EACH ROW EXECUTE FUNCTION gen_part_number();

-- ============================================================
-- CLIENT PORTAL RPC
-- ============================================================

CREATE OR REPLACE FUNCTION get_client_portal_data(p_token UUID)
RETURNS JSON AS $$
DECLARE
  v_custid UUID;
  v_result JSON;
BEGIN
  SELECT custid INTO v_custid FROM customers WHERE token = p_token;
  IF v_custid IS NULL THEN
    RETURN JSON_BUILD_OBJECT('error', 'Invalid or expired token');
  END IF;

  SELECT JSON_BUILD_OBJECT(
    'client', (SELECT ROW_TO_JSON(c) FROM customers c WHERE c.custid = v_custid),
    'projects', COALESCE((
      SELECT JSON_AGG(
        JSON_BUILD_OBJECT(
          'projid',   p.projid,
          'projname', p.projname,
          'projdes',  p.projdes,
          'status',   p.status,
          'priority', p.priority,
          'sdate',    p.sdate,
          'edate',    p.edate,
          'budget',   p.budget,
          'progress', p.progress,
          'cdate',    p.cdate,
          'tasks', COALESCE((
            SELECT JSON_AGG(
              JSON_BUILD_OBJECT(
                'taskid',   t.taskid,
                'taskname', t.taskname,
                'taskdes',  t.taskdes,
                'status',   t.status,
                'priority', t.priority,
                'duedate',  t.duedate,
                'assignto', t.assignto
              ) ORDER BY t.cdate DESC
            )
            FROM tasks t WHERE t.projid = p.projid
          ), '[]'::json)
        ) ORDER BY p.cdate DESC
      )
      FROM projects p WHERE p.custid = v_custid
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_client_portal_data(UUID) TO anon;

-- ============================================================
-- go_live() — wipes demo data, resets sequences
-- ============================================================

CREATE OR REPLACE FUNCTION go_live()
RETURNS void AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  DELETE FROM activity_log;
  DELETE FROM calendar_events;
  DELETE FROM customers;
  DELETE FROM parts;
  UPDATE company SET isdemo = false;
  EXECUTE 'ALTER SEQUENCE client_num_seq  RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE project_num_seq RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE task_num_seq    RESTART WITH 1';
  EXECUTE 'ALTER SEQUENCE part_num_seq    RESTART WITH 1';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION go_live() TO authenticated;

-- ============================================================
-- ADMIN QUERY — SELECT-only SQL editor for admins
-- ============================================================

CREATE OR REPLACE FUNCTION admin_query(p_sql TEXT)
RETURNS JSONB AS $$
DECLARE
  result JSONB;
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  IF NOT (UPPER(TRIM(p_sql)) LIKE 'SELECT%') THEN
    RAISE EXCEPTION 'מותרות שאילתות SELECT בלבד';
  END IF;
  EXECUTE 'SELECT jsonb_agg(row_to_json(t)) FROM (' || p_sql || ') t' INTO result;
  RETURN COALESCE(result, '[]'::jsonb);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION admin_query(TEXT) TO authenticated;

-- ============================================================
-- ADMIN SETUP (run after creating your user in Auth)
-- ============================================================

-- INSERT INTO profiles (id, role)
-- SELECT id, 'admin' FROM auth.users WHERE email = 'your@email.com'
-- ON CONFLICT (id) DO UPDATE SET role = 'admin';
