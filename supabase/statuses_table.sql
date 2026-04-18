-- ============================================================
-- STATUSES TABLE + DEFAULT DATA
-- Run in Supabase SQL Editor
-- ============================================================

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

ALTER TABLE statuses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "statuses_admin" ON statuses;
CREATE POLICY "statuses_admin" ON statuses FOR ALL USING (is_admin());
DROP POLICY IF EXISTS "statuses_read"  ON statuses;
CREATE POLICY "statuses_read"  ON statuses FOR SELECT USING (true);

-- ── Default project statuses ──
INSERT INTO statuses (entity, statuskey, label, color, isdefault, sortorder) VALUES
  ('project', 'planning',  'תכנון',   '#6366f1', true,  1),
  ('project', 'active',    'פעיל',    '#10b981', false, 2),
  ('project', 'paused',    'מושהה',   '#f59e0b', false, 3),
  ('project', 'completed', 'הושלם',   '#3b82f6', false, 4),
  ('project', 'cancelled', 'בוטל',    '#94a3b8', false, 5)
ON CONFLICT (entity, statuskey) DO NOTHING;

-- ── Default task statuses ──
INSERT INTO statuses (entity, statuskey, label, color, isdefault, sortorder) VALUES
  ('task', 'pending',     'ממתין',   '#94a3b8', true,  1),
  ('task', 'in_progress', 'בביצוע',  '#3b82f6', false, 2),
  ('task', 'completed',   'הושלם',   '#10b981', false, 3),
  ('task', 'blocked',     'חסום',    '#ef4444', false, 4)
ON CONFLICT (entity, statuskey) DO NOTHING;

-- ── Default customer statuses ──
INSERT INTO statuses (entity, statuskey, label, color, isdefault, sortorder) VALUES
  ('customer', 'active',   'פעיל',   '#10b981', true,  1),
  ('customer', 'inactive', 'לא פעיל','#94a3b8', false, 2)
ON CONFLICT (entity, statuskey) DO NOTHING;
