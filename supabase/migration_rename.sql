-- ============================================================
-- FULL RENAME MIGRATION
-- Run in Supabase SQL Editor
-- ============================================================

-- 1. RENAME TABLE clients → customers
ALTER TABLE clients RENAME TO customers;

-- 2. CUSTOMERS columns
ALTER TABLE customers RENAME COLUMN id           TO custid;
ALTER TABLE customers RENAME COLUMN name         TO custname;
ALTER TABLE customers RENAME COLUMN company      TO custcomp;
ALTER TABLE customers RENAME COLUMN access_token TO token;
ALTER TABLE customers RENAME COLUMN created_at   TO cdate;
ALTER TABLE customers RENAME COLUMN updated_at   TO udate;
ALTER TABLE customers RENAME COLUMN opening_date TO odate;
ALTER TABLE customers RENAME COLUMN client_number TO custnum;

-- 3. PROJECTS columns
ALTER TABLE projects RENAME COLUMN id             TO projid;
ALTER TABLE projects RENAME COLUMN client_id      TO custid;
ALTER TABLE projects RENAME COLUMN name           TO projname;
ALTER TABLE projects RENAME COLUMN description    TO projdes;
ALTER TABLE projects RENAME COLUMN start_date     TO sdate;
ALTER TABLE projects RENAME COLUMN end_date       TO edate;
ALTER TABLE projects RENAME COLUMN created_at     TO cdate;
ALTER TABLE projects RENAME COLUMN updated_at     TO udate;
ALTER TABLE projects RENAME COLUMN opening_date   TO odate;
ALTER TABLE projects RENAME COLUMN project_number TO projnum;

-- 4. TASKS columns
ALTER TABLE tasks RENAME COLUMN id           TO taskid;
ALTER TABLE tasks RENAME COLUMN project_id   TO projid;
ALTER TABLE tasks RENAME COLUMN title        TO taskname;
ALTER TABLE tasks RENAME COLUMN description  TO taskdes;
ALTER TABLE tasks RENAME COLUMN due_date     TO duedate;
ALTER TABLE tasks RENAME COLUMN assigned_to  TO assignto;
ALTER TABLE tasks RENAME COLUMN created_at   TO cdate;
ALTER TABLE tasks RENAME COLUMN updated_at   TO udate;
ALTER TABLE tasks RENAME COLUMN opening_date TO odate;
ALTER TABLE tasks RENAME COLUMN task_number  TO tasknum;

-- 5. PARTS columns
ALTER TABLE parts RENAME COLUMN part       TO partid;
ALTER TABLE parts RENAME COLUMN created_at TO cdate;
ALTER TABLE parts RENAME COLUMN updated_at TO udate;

-- 6. COMPANY columns
ALTER TABLE company RENAME COLUMN name         TO compname;
ALTER TABLE company RENAME COLUMN owner_name   TO ownname;
ALTER TABLE company RENAME COLUMN tax_number   TO taxnum;
ALTER TABLE company RENAME COLUMN bank_details TO bankdet;
ALTER TABLE company RENAME COLUMN address      TO addr1;
ALTER TABLE company RENAME COLUMN address2     TO addr2;
ALTER TABLE company RENAME COLUMN is_demo      TO isdemo;
ALTER TABLE company RENAME COLUMN updated_at   TO udate;

-- 7. ACTIVITY_LOG columns
ALTER TABLE activity_log RENAME COLUMN id          TO logid;
ALTER TABLE activity_log RENAME COLUMN entity_type TO etype;
ALTER TABLE activity_log RENAME COLUMN entity_id   TO eid;
ALTER TABLE activity_log RENAME COLUMN entity_name TO ename;
ALTER TABLE activity_log RENAME COLUMN created_at  TO cdate;

-- 8. PROFILES columns
ALTER TABLE profiles RENAME COLUMN created_at TO cdate;

-- 9. INDEXES — rebuild
DROP INDEX IF EXISTS idx_projects_client_id;
DROP INDEX IF EXISTS idx_clients_access_token;
DROP INDEX IF EXISTS idx_activity_created_at;
DROP INDEX IF EXISTS idx_tasks_project_id;
CREATE INDEX idx_projects_custid   ON projects(custid);
CREATE INDEX idx_customers_token   ON customers(token);
CREATE INDEX idx_actlog_cdate      ON activity_log(cdate DESC);
CREATE INDEX idx_tasks_projid      ON tasks(projid);

-- 10. TRIGGERS — rebuild updated_at → udate
DROP TRIGGER IF EXISTS clients_updated_at  ON customers;
DROP TRIGGER IF EXISTS projects_updated_at ON projects;
DROP TRIGGER IF EXISTS tasks_updated_at    ON tasks;
DROP TRIGGER IF EXISTS parts_updated_at    ON parts;

CREATE OR REPLACE FUNCTION update_udate()
RETURNS TRIGGER AS $$
BEGIN NEW.udate = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER customers_udate BEFORE UPDATE ON customers FOR EACH ROW EXECUTE FUNCTION update_udate();
CREATE TRIGGER projects_udate  BEFORE UPDATE ON projects  FOR EACH ROW EXECUTE FUNCTION update_udate();
CREATE TRIGGER tasks_udate     BEFORE UPDATE ON tasks     FOR EACH ROW EXECUTE FUNCTION update_udate();
CREATE TRIGGER parts_udate     BEFORE UPDATE ON parts     FOR EACH ROW EXECUTE FUNCTION update_udate();

-- 11. RLS POLICIES — rebuild for customers
DROP POLICY IF EXISTS "clients_admin" ON customers;
CREATE POLICY "customers_admin" ON customers FOR ALL USING (is_admin());

-- 12. SEQUENCE TRIGGERS — update column names
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

-- 13. CLIENT PORTAL RPC — update column references
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
          'projid', p.projid,
          'projname', p.projname,
          'projdes', p.projdes,
          'status', p.status,
          'priority', p.priority,
          'sdate', p.sdate,
          'edate', p.edate,
          'budget', p.budget,
          'progress', p.progress,
          'cdate', p.cdate,
          'tasks', COALESCE((
            SELECT JSON_AGG(
              JSON_BUILD_OBJECT(
                'taskid', t.taskid,
                'taskname', t.taskname,
                'taskdes', t.taskdes,
                'status', t.status,
                'priority', t.priority,
                'duedate', t.duedate,
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

-- 14. go_live() — update references
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

-- 15. admin_query — no changes needed (generic)
