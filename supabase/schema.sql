-- ============================================================
-- PROJECT MANAGER - Supabase Schema + RLS
-- Run this entire file in: Supabase Dashboard → SQL Editor
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- TABLES
-- ============================================================

CREATE TABLE IF NOT EXISTS profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  role TEXT NOT NULL DEFAULT 'client' CHECK (role IN ('admin', 'client')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  company TEXT,
  notes TEXT,
  access_token UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'planning'
    CHECK (status IN ('planning', 'active', 'paused', 'completed', 'cancelled')),
  priority TEXT DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high')),
  start_date DATE,
  end_date DATE,
  budget DECIMAL(12,2),
  progress INTEGER DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'in_progress', 'completed', 'blocked')),
  priority TEXT DEFAULT 'medium'
    CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
  due_date DATE,
  assigned_to TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS activity_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type TEXT NOT NULL CHECK (entity_type IN ('client', 'project', 'task')),
  entity_id UUID NOT NULL,
  entity_name TEXT,
  action TEXT NOT NULL,
  details JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_projects_client_id ON projects(client_id);
CREATE INDEX IF NOT EXISTS idx_tasks_project_id ON tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_activity_created_at ON activity_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clients_access_token ON clients(access_token);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_log ENABLE ROW LEVEL SECURITY;

-- Helper: is current user admin?
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Profiles: see own or admin sees all
DROP POLICY IF EXISTS "profiles_select" ON profiles;
CREATE POLICY "profiles_select" ON profiles
  FOR SELECT USING (id = auth.uid() OR is_admin());

DROP POLICY IF EXISTS "profiles_admin_all" ON profiles;
CREATE POLICY "profiles_admin_all" ON profiles
  FOR ALL USING (is_admin());

-- Clients, Projects, Tasks, Activity: admin only
DROP POLICY IF EXISTS "clients_admin" ON clients;
CREATE POLICY "clients_admin" ON clients FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "projects_admin" ON projects;
CREATE POLICY "projects_admin" ON projects FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "tasks_admin" ON tasks;
CREATE POLICY "tasks_admin" ON tasks FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "activity_admin" ON activity_log;
CREATE POLICY "activity_admin" ON activity_log FOR ALL USING (is_admin());

-- ============================================================
-- CLIENT PORTAL RPC (bypasses RLS — read-only for clients)
-- ============================================================

CREATE OR REPLACE FUNCTION get_client_portal_data(p_token UUID)
RETURNS JSON AS $$
DECLARE
  v_client_id UUID;
  v_result JSON;
BEGIN
  SELECT id INTO v_client_id FROM clients WHERE access_token = p_token;
  IF v_client_id IS NULL THEN
    RETURN JSON_BUILD_OBJECT('error', 'Invalid or expired token');
  END IF;

  SELECT JSON_BUILD_OBJECT(
    'client', (SELECT ROW_TO_JSON(c) FROM clients c WHERE c.id = v_client_id),
    'projects', COALESCE((
      SELECT JSON_AGG(
        JSON_BUILD_OBJECT(
          'id', p.id,
          'name', p.name,
          'description', p.description,
          'status', p.status,
          'priority', p.priority,
          'start_date', p.start_date,
          'end_date', p.end_date,
          'budget', p.budget,
          'progress', p.progress,
          'created_at', p.created_at,
          'tasks', COALESCE((
            SELECT JSON_AGG(
              JSON_BUILD_OBJECT(
                'id', t.id,
                'title', t.title,
                'description', t.description,
                'status', t.status,
                'priority', t.priority,
                'due_date', t.due_date,
                'assigned_to', t.assigned_to
              ) ORDER BY t.created_at DESC
            )
            FROM tasks t WHERE t.project_id = p.id
          ), '[]'::json)
        ) ORDER BY p.created_at DESC
      )
      FROM projects p WHERE p.client_id = v_client_id
    ), '[]'::json)
  ) INTO v_result;

  RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Allow anonymous access for client portal
GRANT EXECUTE ON FUNCTION get_client_portal_data(UUID) TO anon;

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-create profile on signup
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

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clients_updated_at BEFORE UPDATE ON clients
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER projects_updated_at BEFORE UPDATE ON projects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================
-- ADMIN SETUP (run after creating your user in Auth)
-- Replace the email with your actual admin email
-- ============================================================

-- INSERT INTO profiles (id, role)
-- SELECT id, 'admin' FROM auth.users WHERE email = 'your@email.com'
-- ON CONFLICT (id) DO UPDATE SET role = 'admin';

-- ============================================================
-- DEMO MODE — run in Supabase SQL Editor after initial setup
-- ============================================================

-- Add is_demo flag to company table (true = demo, false = live)
ALTER TABLE company ADD COLUMN IF NOT EXISTS is_demo BOOLEAN DEFAULT true;

-- go_live(): atomically wipes all demo data and activates the company
CREATE OR REPLACE FUNCTION go_live()
RETURNS void AS $$
BEGIN
  IF NOT is_admin() THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;
  DELETE FROM activity_log;
  DELETE FROM calendar_events;
  DELETE FROM clients; -- cascades to projects + tasks
  UPDATE company SET is_demo = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION go_live() TO authenticated;
