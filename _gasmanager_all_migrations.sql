-- ============ 20260608000000_foundation.sql ============
-- ============================================================
-- Migration: 20260608000000_foundation
-- Agente WhatsApp — Full schema foundation (F0-A2)
-- ============================================================

-- ============================================
-- Extensions
-- ============================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ============================================
-- Trigger function: update_updated_at
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Enums
-- ============================================

DO $$ BEGIN
  CREATE TYPE conversation_state AS ENUM (
    'ai_active',
    'human_active',
    'handoff_pending',
    'waiting_reply',
    'paused',
    'closed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE conversation_channel AS ENUM ('whatsapp');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE message_direction AS ENUM ('in', 'out');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE message_type AS ENUM (
    'text', 'audio', 'image', 'document', 'video', 'sticker', 'location', 'template', 'system'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE message_status AS ENUM ('queued', 'sent', 'delivered', 'read', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE batch_status AS ENUM ('buffering', 'flushed', 'processed', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE template_status AS ENUM ('draft', 'submitted', 'approved', 'rejected', 'paused');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE prompt_version_state AS ENUM ('draft', 'published');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE prompt_scope AS ENUM ('global', 'number', 'campaign', 'segment', 'mode');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE workspace_role AS ENUM ('admin', 'manager', 'agent', 'viewer');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE contact_stage AS ENUM ('new', 'engaged', 'qualified', 'customer', 'lost');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE integration_provider AS ENUM ('highlevel', 'openrouter', 'ycloud', 'caldotcom');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================
-- Table: workspaces (tenant root — must exist before memberships)
-- ============================================
CREATE TABLE IF NOT EXISTS workspaces (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  logo_url TEXT,
  settings JSONB DEFAULT '{
    "timezone": "America/Mexico_City",
    "language": "es"
  }'::jsonb NOT NULL,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_workspaces_slug ON workspaces(slug);

-- ============================================
-- Table: users (profile linked to auth.users)
-- ============================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- Table: memberships (user <-> workspace N:M)
-- ============================================
CREATE TABLE IF NOT EXISTS memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role workspace_role NOT NULL DEFAULT 'agent',
  is_active BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_memberships_workspace ON memberships(workspace_id, is_active);
CREATE INDEX IF NOT EXISTS idx_memberships_user ON memberships(user_id, is_active);

-- ============================================
-- RLS helper functions (depend on memberships)
-- ============================================
CREATE OR REPLACE FUNCTION auth_workspace_ids()
RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT m.workspace_id
  FROM memberships m
  WHERE m.user_id = auth.uid() AND m.is_active = TRUE;
$$;

CREATE OR REPLACE FUNCTION auth_has_role(p_workspace UUID, p_roles workspace_role[])
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM memberships m
    WHERE m.user_id = auth.uid()
      AND m.workspace_id = p_workspace
      AND m.is_active = TRUE
      AND m.role = ANY(p_roles)
  );
$$;

-- ============================================
-- Table: permissions (fine-grained capability overrides)
-- ============================================
CREATE TABLE IF NOT EXISTS permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  capability TEXT NOT NULL,
  granted BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id, user_id, capability)
);
CREATE INDEX IF NOT EXISTS idx_permissions_lookup ON permissions(workspace_id, user_id);

-- ============================================
-- Table: contacts (CRM)
-- ============================================
CREATE TABLE IF NOT EXISTS contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  phone TEXT NOT NULL,
  name TEXT,
  email TEXT,
  source TEXT,
  owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
  stage contact_stage DEFAULT 'new' NOT NULL,
  tags TEXT[] DEFAULT '{}'::text[] NOT NULL,
  custom_fields JSONB DEFAULT '{}'::jsonb NOT NULL,
  opt_in BOOLEAN DEFAULT FALSE NOT NULL,
  opt_in_at TIMESTAMPTZ,
  hl_contact_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT uq_contacts_workspace_phone UNIQUE (workspace_id, phone)
);

CREATE INDEX IF NOT EXISTS idx_contacts_workspace         ON contacts(workspace_id);
CREATE INDEX IF NOT EXISTS idx_contacts_owner             ON contacts(workspace_id, owner_id);
CREATE INDEX IF NOT EXISTS idx_contacts_stage             ON contacts(workspace_id, stage);
CREATE INDEX IF NOT EXISTS idx_contacts_hl                ON contacts(workspace_id, hl_contact_id) WHERE hl_contact_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_contacts_tags_gin          ON contacts USING GIN (tags);
CREATE INDEX IF NOT EXISTS idx_contacts_custom_fields_gin ON contacts USING GIN (custom_fields jsonb_path_ops);
CREATE INDEX IF NOT EXISTS idx_contacts_name_trgm         ON contacts USING GIN (name gin_trgm_ops);

DROP TRIGGER IF EXISTS trg_contacts_updated_at ON contacts;
CREATE TRIGGER trg_contacts_updated_at
  BEFORE UPDATE ON contacts FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: conversations (state machine + 24h window)
-- ============================================
CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  contact_id UUID NOT NULL REFERENCES contacts(id) ON DELETE CASCADE,
  channel conversation_channel DEFAULT 'whatsapp' NOT NULL,
  state conversation_state DEFAULT 'ai_active' NOT NULL,
  ai_enabled BOOLEAN DEFAULT TRUE NOT NULL,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  last_message_at TIMESTAMPTZ,
  window_expires_at TIMESTAMPTZ,
  unread_count INT DEFAULT 0 NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  CONSTRAINT uq_conversations_contact UNIQUE (workspace_id, contact_id, channel)
);

CREATE INDEX IF NOT EXISTS idx_conversations_workspace ON conversations(workspace_id);
CREATE INDEX IF NOT EXISTS idx_conversations_inbox     ON conversations(workspace_id, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_state     ON conversations(workspace_id, state);
CREATE INDEX IF NOT EXISTS idx_conversations_assigned  ON conversations(workspace_id, assigned_to);

DROP TRIGGER IF EXISTS trg_conversations_updated_at ON conversations;
CREATE TRIGGER trg_conversations_updated_at
  BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: message_batches (smart buffer, module 2)
-- ============================================
CREATE TABLE IF NOT EXISTS message_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  status batch_status DEFAULT 'buffering' NOT NULL,
  silence_ms INT NOT NULL DEFAULT 30000,
  flush_at TIMESTAMPTZ,
  message_count INT DEFAULT 0 NOT NULL,
  merged_text TEXT,
  meta JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_batches_conversation ON message_batches(conversation_id, status);
CREATE INDEX IF NOT EXISTS idx_batches_flush        ON message_batches(status, flush_at) WHERE status = 'buffering';

DROP TRIGGER IF EXISTS trg_batches_updated_at ON message_batches;
CREATE TRIGGER trg_batches_updated_at
  BEFORE UPDATE ON message_batches FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: messages (in/out, media, wamid, batch)
-- templates FK added after templates table
-- ============================================
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  direction message_direction NOT NULL,
  type message_type NOT NULL DEFAULT 'text',
  body TEXT,
  media JSONB,
  wamid TEXT,
  batch_id UUID REFERENCES message_batches(id) ON DELETE SET NULL,
  template_id UUID,
  status message_status,
  error_message TEXT,
  sender_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  meta JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_messages_wamid
  ON messages(workspace_id, wamid)
  WHERE wamid IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_workspace    ON messages(workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_batch        ON messages(batch_id) WHERE batch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_meta_gin     ON messages USING GIN (meta jsonb_path_ops);

-- ============================================
-- Table: business_info (module 5)
-- ============================================
CREATE TABLE IF NOT EXISTS business_info (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  structured JSONB DEFAULT '{}'::jsonb NOT NULL,
  free_text TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id)
);
CREATE INDEX IF NOT EXISTS idx_business_info_structured_gin ON business_info USING GIN (structured jsonb_path_ops);

DROP TRIGGER IF EXISTS trg_business_info_updated_at ON business_info;
CREATE TRIGGER trg_business_info_updated_at
  BEFORE UPDATE ON business_info FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: prompts (module 6)
-- ============================================
CREATE TABLE IF NOT EXISTS prompts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  scope prompt_scope NOT NULL,
  scope_ref TEXT,
  name TEXT NOT NULL,
  active_version_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id, scope, scope_ref)
);
CREATE INDEX IF NOT EXISTS idx_prompts_workspace_scope ON prompts(workspace_id, scope, scope_ref);

-- ============================================
-- Table: prompt_versions (draft/published)
-- ============================================
CREATE TABLE IF NOT EXISTS prompt_versions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  prompt_id UUID NOT NULL REFERENCES prompts(id) ON DELETE CASCADE,
  version INT NOT NULL,
  state prompt_version_state DEFAULT 'draft' NOT NULL,
  body TEXT NOT NULL,
  variables JSONB DEFAULT '[]'::jsonb NOT NULL,
  model_overrides JSONB DEFAULT '{}'::jsonb NOT NULL,
  guardrails JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  published_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (prompt_id, version)
);
CREATE INDEX IF NOT EXISTS idx_prompt_versions_prompt ON prompt_versions(prompt_id, state);

-- Back-patch FK: prompts.active_version_id -> prompt_versions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_prompts_active_version'
      AND table_name = 'prompts'
  ) THEN
    ALTER TABLE prompts
      ADD CONSTRAINT fk_prompts_active_version
      FOREIGN KEY (active_version_id) REFERENCES prompt_versions(id) ON DELETE SET NULL;
  END IF;
END $$;

DROP TRIGGER IF EXISTS trg_prompts_updated_at ON prompts;
CREATE TRIGGER trg_prompts_updated_at
  BEFORE UPDATE ON prompts FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: templates (Meta compliance — module 10)
-- ============================================
CREATE TABLE IF NOT EXISTS templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  language TEXT NOT NULL DEFAULT 'es',
  category TEXT NOT NULL CHECK (category IN ('marketing', 'utility', 'authentication')),
  status template_status NOT NULL DEFAULT 'draft',
  body_template TEXT NOT NULL,
  components JSONB DEFAULT '{}'::jsonb NOT NULL,
  variables JSONB DEFAULT '[]'::jsonb NOT NULL,
  provider_template_id TEXT,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id, name, language)
);
CREATE INDEX IF NOT EXISTS idx_templates_workspace_status ON templates(workspace_id, status);
CREATE INDEX IF NOT EXISTS idx_templates_components_gin    ON templates USING GIN (components jsonb_path_ops);

DROP TRIGGER IF EXISTS trg_templates_updated_at ON templates;
CREATE TRIGGER trg_templates_updated_at
  BEFORE UPDATE ON templates FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Back-patch FK: messages.template_id -> templates
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_messages_template'
      AND table_name = 'messages'
  ) THEN
    ALTER TABLE messages
      ADD CONSTRAINT fk_messages_template
      FOREIGN KEY (template_id) REFERENCES templates(id) ON DELETE SET NULL;
  END IF;
END $$;

-- ============================================
-- Table: tools (global catalog — module 7, read-only for clients)
-- ============================================
CREATE TABLE IF NOT EXISTS tools (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  schema JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

-- ============================================
-- Table: tool_configs (activation + credentials per workspace)
-- ============================================
CREATE TABLE IF NOT EXISTS tool_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  tool_id UUID NOT NULL REFERENCES tools(id) ON DELETE CASCADE,
  enabled BOOLEAN DEFAULT FALSE NOT NULL,
  credentials JSONB DEFAULT '{}'::jsonb NOT NULL,
  config JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id, tool_id)
);
CREATE INDEX IF NOT EXISTS idx_tool_configs_workspace ON tool_configs(workspace_id, enabled);

DROP TRIGGER IF EXISTS trg_tool_configs_updated_at ON tool_configs;
CREATE TRIGGER trg_tool_configs_updated_at
  BEFORE UPDATE ON tool_configs FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: integrations (HighLevel, OpenRouter, YCloud — modules 11/13)
-- ============================================
CREATE TABLE IF NOT EXISTS integrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  provider integration_provider NOT NULL,
  enabled BOOLEAN DEFAULT FALSE NOT NULL,
  credentials JSONB DEFAULT '{}'::jsonb NOT NULL,
  oauth_tokens JSONB DEFAULT '{}'::jsonb NOT NULL,
  config JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id, provider)
);
CREATE INDEX IF NOT EXISTS idx_integrations_workspace ON integrations(workspace_id, provider);

DROP TRIGGER IF EXISTS trg_integrations_updated_at ON integrations;
CREATE TRIGGER trg_integrations_updated_at
  BEFORE UPDATE ON integrations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: kb_documents (module 12 — Knowledge Base)
-- ============================================
CREATE TABLE IF NOT EXISTS kb_documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  source_type TEXT NOT NULL DEFAULT 'doc' CHECK (source_type IN ('doc', 'faq', 'url', 'snippet')),
  source_url TEXT,
  content TEXT,
  meta JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_kb_documents_workspace ON kb_documents(workspace_id);

DROP TRIGGER IF EXISTS trg_kb_documents_updated_at ON kb_documents;
CREATE TRIGGER trg_kb_documents_updated_at
  BEFORE UPDATE ON kb_documents FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: kb_chunks (pgvector embeddings)
-- ============================================
CREATE TABLE IF NOT EXISTS kb_chunks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  document_id UUID NOT NULL REFERENCES kb_documents(id) ON DELETE CASCADE,
  chunk_index INT NOT NULL,
  content TEXT NOT NULL,
  embedding vector(1536),
  meta JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (document_id, chunk_index)
);
CREATE INDEX IF NOT EXISTS idx_kb_chunks_workspace ON kb_chunks(workspace_id);
CREATE INDEX IF NOT EXISTS idx_kb_chunks_document  ON kb_chunks(document_id);
CREATE INDEX IF NOT EXISTS idx_kb_chunks_embedding_hnsw
  ON kb_chunks USING hnsw (embedding vector_cosine_ops);

-- ============================================
-- Table: setter_configs (module 8: knockout + scoring)
-- ============================================
CREATE TABLE IF NOT EXISTS setter_configs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  enabled BOOLEAN DEFAULT FALSE NOT NULL,
  questions JSONB DEFAULT '[]'::jsonb NOT NULL,
  knockout_rules JSONB DEFAULT '[]'::jsonb NOT NULL,
  scoring JSONB DEFAULT '{}'::jsonb NOT NULL,
  post_action JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  UNIQUE (workspace_id, name)
);
CREATE INDEX IF NOT EXISTS idx_setter_configs_workspace ON setter_configs(workspace_id, enabled);

DROP TRIGGER IF EXISTS trg_setter_configs_updated_at ON setter_configs;
CREATE TRIGGER trg_setter_configs_updated_at
  BEFORE UPDATE ON setter_configs FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: schedules (module 9 — scheduling config)
-- ============================================
CREATE TABLE IF NOT EXISTS schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  mode TEXT NOT NULL DEFAULT 'external_link' CHECK (mode IN ('external_link', 'highlevel')),
  config JSONB DEFAULT '{}'::jsonb NOT NULL,
  enabled BOOLEAN DEFAULT TRUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_schedules_workspace ON schedules(workspace_id, enabled);

DROP TRIGGER IF EXISTS trg_schedules_updated_at ON schedules;
CREATE TRIGGER trg_schedules_updated_at
  BEFORE UPDATE ON schedules FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: appointments (booked appointments)
-- ============================================
CREATE TABLE IF NOT EXISTS appointments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  contact_id UUID REFERENCES contacts(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  schedule_id UUID REFERENCES schedules(id) ON DELETE SET NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'booked' CHECK (status IN ('booked', 'confirmed', 'cancelled', 'completed', 'no_show')),
  hl_appointment_id TEXT,
  meta JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_appointments_workspace ON appointments(workspace_id, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_appointments_contact   ON appointments(contact_id);

DROP TRIGGER IF EXISTS trg_appointments_updated_at ON appointments;
CREATE TRIGGER trg_appointments_updated_at
  BEFORE UPDATE ON appointments FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- Table: events (observability / audit log — module 17)
-- ============================================
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  level TEXT NOT NULL DEFAULT 'info' CHECK (level IN ('debug', 'info', 'warn', 'error')),
  payload JSONB DEFAULT '{}'::jsonb NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_events_workspace    ON events(workspace_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_conversation ON events(conversation_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_type         ON events(workspace_id, type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_events_payload_gin  ON events USING GIN (payload jsonb_path_ops);

-- ============================================
-- Realtime: messages + conversations
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE conversations;
ALTER TABLE messages REPLICA IDENTITY FULL;
ALTER TABLE conversations REPLICA IDENTITY FULL;

-- ============================================================
-- RLS — Row Level Security
-- All tenant-scoped tables use workspace_id for isolation.
-- service_role bypasses RLS (used by webhook handlers).
-- ============================================================

-- ---- workspaces ----
ALTER TABLE workspaces ENABLE ROW LEVEL SECURITY;

CREATE POLICY "workspaces_select_members"
  ON workspaces FOR SELECT
  USING (id IN (SELECT auth_workspace_ids()));

CREATE POLICY "workspaces_update_admins"
  ON workspaces FOR UPDATE
  USING (auth_has_role(id, ARRAY['admin']::workspace_role[]))
  WITH CHECK (auth_has_role(id, ARRAY['admin']::workspace_role[]));

CREATE POLICY "workspaces_delete_admins"
  ON workspaces FOR DELETE
  USING (auth_has_role(id, ARRAY['admin']::workspace_role[]));

-- ---- users ----
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_select_authenticated"
  ON users FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "users_update_own"
  ON users FOR UPDATE
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- ---- memberships ----
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "memberships_select_members"
  ON memberships FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "memberships_insert_admins"
  ON memberships FOR INSERT
  WITH CHECK (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]));

CREATE POLICY "memberships_update_admins"
  ON memberships FOR UPDATE
  USING (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]))
  WITH CHECK (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]));

CREATE POLICY "memberships_delete_admins"
  ON memberships FOR DELETE
  USING (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]));

-- ---- permissions ----
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "permissions_select_admins"
  ON permissions FOR SELECT
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin']::workspace_role[])
  );

CREATE POLICY "permissions_insert_admins"
  ON permissions FOR INSERT
  WITH CHECK (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]));

CREATE POLICY "permissions_update_admins"
  ON permissions FOR UPDATE
  USING (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]))
  WITH CHECK (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]));

CREATE POLICY "permissions_delete_admins"
  ON permissions FOR DELETE
  USING (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]));

-- ---- contacts (from §3.10) ----
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ws members read contacts"
  ON contacts FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "ws operators write contacts"
  ON contacts FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  );

-- ---- conversations (from §3.10) ----
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ws members read conversations"
  ON conversations FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "ws agents update conversations"
  ON conversations FOR UPDATE
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND (
      auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
      OR assigned_to = auth.uid()
    )
  )
  WITH CHECK (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "ws operators insert conversations"
  ON conversations FOR INSERT
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  );

CREATE POLICY "ws admins delete conversations"
  ON conversations FOR DELETE
  USING (auth_has_role(workspace_id, ARRAY['admin']::workspace_role[]));

-- ---- messages (from §3.10) ----
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ws members read messages"
  ON messages FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "ws agents send messages"
  ON messages FOR INSERT
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND direction = 'out'
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  );

-- ---- message_batches ----
ALTER TABLE message_batches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "message_batches_select"
  ON message_batches FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "message_batches_write"
  ON message_batches FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  );

-- ---- business_info ----
ALTER TABLE business_info ENABLE ROW LEVEL SECURITY;

CREATE POLICY "business_info_select"
  ON business_info FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "business_info_write"
  ON business_info FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- prompts ----
ALTER TABLE prompts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "prompts_select"
  ON prompts FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "prompts_write"
  ON prompts FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- prompt_versions ----
ALTER TABLE prompt_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "prompt_versions_select"
  ON prompt_versions FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "prompt_versions_write"
  ON prompt_versions FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- templates ----
ALTER TABLE templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "templates_select"
  ON templates FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "templates_write"
  ON templates FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- tools (global catalog — SELECT only for authenticated clients) ----
ALTER TABLE tools ENABLE ROW LEVEL SECURITY;

CREATE POLICY "tools_select_authenticated"
  ON tools FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- No INSERT/UPDATE/DELETE from client; managed by service_role only.

-- ---- tool_configs (credentials must not be readable by non-admins from client) ----
ALTER TABLE tool_configs ENABLE ROW LEVEL SECURITY;

-- Admins/managers see the full row (credentials read server-side only via service_role)
CREATE POLICY "tool_configs_select_admins"
  ON tool_configs FOR SELECT
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

CREATE POLICY "tool_configs_write_admins"
  ON tool_configs FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin']::workspace_role[])
  );

-- ---- integrations (credentials/oauth_tokens — server-side only via service_role) ----
ALTER TABLE integrations ENABLE ROW LEVEL SECURITY;

-- Admins/managers can see integrations metadata (credentials decrypted server-side only)
CREATE POLICY "integrations_select_admins"
  ON integrations FOR SELECT
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

CREATE POLICY "integrations_write_admins"
  ON integrations FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin']::workspace_role[])
  );

-- ---- kb_documents ----
ALTER TABLE kb_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kb_documents_select"
  ON kb_documents FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "kb_documents_write"
  ON kb_documents FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- kb_chunks ----
ALTER TABLE kb_chunks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kb_chunks_select"
  ON kb_chunks FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "kb_chunks_write"
  ON kb_chunks FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- setter_configs ----
ALTER TABLE setter_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "setter_configs_select"
  ON setter_configs FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "setter_configs_write"
  ON setter_configs FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- schedules ----
ALTER TABLE schedules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "schedules_select"
  ON schedules FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "schedules_write"
  ON schedules FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- appointments ----
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "appointments_select"
  ON appointments FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "appointments_write"
  ON appointments FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  );

-- ---- events (observability — append-only from app, read for admins/managers) ----
ALTER TABLE events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "events_select"
  ON events FOR SELECT
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

CREATE POLICY "events_insert"
  ON events FOR INSERT
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager','agent']::workspace_role[])
  );

-- ============================================================
-- End of migration: 20260608000000_foundation
-- 20 tables, 12 enums, RLS on all tables, Realtime on messages+conversations
-- ============================================================

-- ============ 20260608000002_buffer_rpc.sql ============
-- ============================================================
-- Migration: 20260608000002_buffer_rpc
-- Agente WhatsApp — Buffer RPCs (F2-T1)
--
-- Creates two SECURITY DEFINER functions for atomic batch processing:
--   1. claim_next_batch()  — claims ONE ready batch, prevents double-processing
--   2. cancel_batch()      — marks a batch as dead-letter after max retries
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- RPC 1: claim_next_batch
-- Atomically claims one batch for processing.
--
-- Eligible batches:
--   a) status = 'buffering' AND flush_at < NOW()  (ready)
--   b) status = 'processing' AND updated_at < NOW() - 5min (stale/stuck worker)
--
-- Uses FOR UPDATE SKIP LOCKED — the ONLY correct way to prevent
-- two cron workers from claiming the same batch (SCALE-01).
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION claim_next_batch()
RETURNS SETOF public.message_batches
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  RETURN QUERY
  WITH candidate AS (
    SELECT id FROM public.message_batches
    WHERE status IN ('buffering', 'processing')
      AND (
        -- Ready buffering batches whose silence window has elapsed
        (status = 'buffering' AND flush_at < NOW())
        OR
        -- Reclaim stale processing batches (lease > 5 min = stuck worker)
        (status = 'processing' AND updated_at < NOW() - INTERVAL '5 minutes')
      )
    ORDER BY flush_at ASC
    LIMIT 1
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.message_batches
    SET status = 'processing',
        updated_at = NOW()
  FROM candidate
  WHERE public.message_batches.id = candidate.id
  RETURNING public.message_batches.*;
END;
$$;

-- ──────────────────────────────────────────────────────────
-- RPC 2: cancel_batch
-- Marks a batch as dead-letter (cancelled) after too many failures.
-- Only transitions from 'processing' to prevent accidental cancellation
-- of batches that were already processed or re-claimed.
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION cancel_batch(p_batch_id UUID)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.message_batches
  SET status = 'cancelled',
      updated_at = NOW(),
      meta = meta || jsonb_build_object('cancelled_reason', 'max_retries_exceeded')
  WHERE id = p_batch_id AND status = 'processing';
END;
$$;

-- ============ 20260608000003_24h_guard.sql ============
-- 24h window guard trigger (SEC-04)
-- Blocks outbound free text when conversation window has expired.
-- override_admin flag in message.meta bypasses the guard for admin role
-- and logs a WINDOW_OVERRIDE event.
CREATE OR REPLACE FUNCTION public.check_outbound_24h_window()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  conv_window_expires_at TIMESTAMPTZ;
  conv_workspace_id UUID;
BEGIN
  -- Only enforce on outbound non-template messages
  IF NEW.direction <> 'out' OR NEW.type = 'template' THEN
    RETURN NEW;
  END IF;

  SELECT window_expires_at, workspace_id
    INTO conv_window_expires_at, conv_workspace_id
    FROM public.conversations
   WHERE id = NEW.conversation_id;

  -- No window set (null) → allow (first interaction)
  IF conv_window_expires_at IS NULL THEN
    RETURN NEW;
  END IF;

  -- Window open → allow
  IF NOW() <= conv_window_expires_at THEN
    RETURN NEW;
  END IF;

  -- Window expired: check for admin override flag
  IF (NEW.meta ->> 'override_admin')::boolean IS TRUE THEN
    -- Log the override event
    INSERT INTO public.events (workspace_id, conversation_id, type, level, payload)
    VALUES (
      conv_workspace_id,
      NEW.conversation_id,
      'WINDOW_OVERRIDE',
      'warn',
      jsonb_build_object('sender_user_id', NEW.sender_user_id, 'body_preview', left(COALESCE(NEW.body,''), 40))
    );
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'WINDOW_EXPIRED: free text outside 24h window. Use an approved template.';
END;
$$;

CREATE TRIGGER trg_messages_24h_window
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.check_outbound_24h_window();

-- ============ 20260608000004_crm_indexes.sql ============
-- Extra indexes for CRM dedupe and HL sync
-- Most indexes were created in F0. These add hl_contact_id lookup.
CREATE INDEX IF NOT EXISTS idx_contacts_hl_contact_id
  ON public.contacts(workspace_id, hl_contact_id)
  WHERE hl_contact_id IS NOT NULL;

-- Partial index for opt-out contacts (fast guard check)
CREATE INDEX IF NOT EXISTS idx_contacts_opt_out
  ON public.contacts(workspace_id, phone)
  WHERE opt_in = FALSE;

-- ============ 20260608000006_tools_sensitivity.sql ============
-- Add sensitivity column to tools catalog (SEC-01)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name='tools' AND column_name='sensitivity') THEN
    ALTER TABLE public.tools ADD COLUMN sensitivity TEXT NOT NULL DEFAULT 'read'
      CHECK (sensitivity IN ('read', 'write', 'sensitive'));
  END IF;
END $$;

-- Seed built-in tools
INSERT INTO public.tools (key, name, description, schema, sensitivity) VALUES
  ('echo',             'Echo',                'Test tool — echoes back a message',
   '{"type":"object","properties":{"msg":{"type":"string"}},"required":["msg"]}', 'read'),
  ('schedule_link',    'Agendamiento (link)', 'Returns a scheduling link for the contact to book an appointment',
   '{"type":"object","properties":{"contact_name":{"type":"string"}},"required":[]}', 'read'),
  ('schedule_highlevel','Agendar en HighLevel','Creates an appointment directly in HighLevel CRM',
   '{"type":"object","properties":{"contact_name":{"type":"string"},"datetime_iso":{"type":"string"},"calendar_id":{"type":"string"}},"required":["datetime_iso"]}', 'write'),
  ('custom_webhook',   'Webhook personalizado','Calls a custom HTTPS webhook URL with a JSON payload',
   '{"type":"object","properties":{"payload":{"type":"object"}},"required":["payload"]}', 'sensitive')
ON CONFLICT (key) DO UPDATE SET sensitivity=EXCLUDED.sensitivity, name=EXCLUDED.name;

-- ============ 20260608000007_media_storage.sql ============
-- Migration: whatsapp-media storage bucket + RLS policies
-- F8-D1: Multimedia support for inbound media messages
--
-- NOTE: The INSERT into storage.buckets may fail if the service role lacks
-- direct storage schema write access. In that case, create the bucket via
-- the Supabase dashboard (Storage → New bucket) with these settings:
--   Name: whatsapp-media
--   Public: false
--   File size limit: 50 MB
--   Allowed MIME types: (see list below)
-- Then re-run this migration so the RLS policies are applied.

-- Create the private bucket for WhatsApp media files
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'whatsapp-media',
  'whatsapp-media',
  false,
  52428800, -- 50 MB
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'audio/ogg',
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/wav',
    'video/mp4',
    'video/3gpp',
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/octet-stream'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- RLS: service role can upload (used by media-handler.ts running server-side)
CREATE POLICY "service_role_upload_media"
ON storage.objects
FOR INSERT
TO service_role
WITH CHECK (bucket_id = 'whatsapp-media');

-- RLS: service role can read (used to generate signed URLs)
CREATE POLICY "service_role_read_media"
ON storage.objects
FOR SELECT
TO service_role
USING (bucket_id = 'whatsapp-media');

-- RLS: service role can delete (for future cleanup jobs)
CREATE POLICY "service_role_delete_media"
ON storage.objects
FOR DELETE
TO service_role
USING (bucket_id = 'whatsapp-media');

-- Authenticated users can read objects that belong to their workspace.
-- Path convention: {workspace_id}/{conversation_id}/{filename}
-- The workspace_id is the first path segment, which we match via the auth.uid()
-- lookup against workspace_members (adjust table/column names if they differ).
CREATE POLICY "workspace_member_read_media"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'whatsapp-media'
  AND (
    -- Allow if the user belongs to the workspace encoded in the first path segment
    EXISTS (
      SELECT 1
      FROM public.memberships wm
      WHERE wm.user_id = auth.uid()
        AND wm.is_active = TRUE
        AND wm.workspace_id::text = split_part(name, '/', 1)
    )
  )
);

-- ============ 20260608000008_sec02_function_hardening.sql ============
-- SEC-02 cierre: harden SECURITY DEFINER functions
-- Fixes: function_search_path_mutable + anon_security_definer_function_executable

-- Fix function_search_path_mutable warnings
ALTER FUNCTION public.update_updated_at() SET search_path = '';
ALTER FUNCTION public.auth_workspace_ids() SET search_path = '';
ALTER FUNCTION public.auth_has_role(uuid, public.workspace_role[]) SET search_path = '';

-- Revoke anon+authenticated execute from internal worker functions
-- (these are called server-side via service_role only — never by end users)
REVOKE EXECUTE ON FUNCTION public.cancel_batch(uuid) FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.claim_next_batch() FROM anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.check_outbound_24h_window() FROM anon;
-- NOTE: there is no handle_new_user() function/trigger in this schema —
-- public.users rows are created explicitly (seed + agency actions), not by a
-- signup trigger. The previous REVOKE on it errored a clean db push; removed.

-- Revoke anon from RLS helpers
-- (authenticated users still invoke them implicitly via RLS policy evaluation)
REVOKE EXECUTE ON FUNCTION public.auth_workspace_ids() FROM anon;
REVOKE EXECUTE ON FUNCTION public.auth_has_role(uuid, public.workspace_role[]) FROM anon;

-- ============ 20260609000001_super_admin.sql ============
-- ============================================================
-- Migration: 20260609000001_super_admin
-- Agente WhatsApp — Super admin flag + onboarding policies
-- ============================================================

-- Add is_super_admin flag to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_super_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- Helper function: check if current user is super admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT COALESCE(
    (SELECT is_super_admin FROM public.users WHERE id = auth.uid()),
    FALSE
  );
$$;

-- Super admins can see ALL workspaces (bypass the normal membership filter)
DROP POLICY IF EXISTS "workspaces_select_members" ON public.workspaces;
CREATE POLICY "workspaces_select_members" ON public.workspaces
  FOR SELECT USING (
    id IN (SELECT auth_workspace_ids())
    OR public.is_super_admin()
  );

-- Super admins can see ALL memberships
DROP POLICY IF EXISTS "memberships_select_members" ON public.memberships;
CREATE POLICY "memberships_select_members" ON public.memberships
  FOR SELECT USING (
    workspace_id IN (SELECT auth_workspace_ids())
    OR public.is_super_admin()
  );

-- Super admins can INSERT new workspaces (for creating client workspaces)
CREATE POLICY "super_admin_insert_workspaces" ON public.workspaces
  FOR INSERT WITH CHECK (public.is_super_admin());

-- Super admins or workspace admins can INSERT memberships
CREATE POLICY "super_admin_insert_memberships" ON public.memberships
  FOR INSERT WITH CHECK (
    public.is_super_admin()
    OR auth_has_role(workspace_id, ARRAY['admin']::workspace_role[])
  );

-- REVOKE anon from new function
REVOKE EXECUTE ON FUNCTION public.is_super_admin() FROM anon;

-- ============================================================
-- End of migration: 20260609000001_super_admin
-- ============================================================

-- ============ 20260609000002_automation_rules.sql ============
-- ============================================================
-- Migration: 20260609000002_automation_rules
-- Agente WhatsApp — G3 Automation Triggers table
-- ============================================================

CREATE TABLE IF NOT EXISTS public.automation_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id UUID NOT NULL REFERENCES public.workspaces(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  trigger_type TEXT NOT NULL CHECK (trigger_type IN (
    'first_message',      -- when contact writes for first time
    'inactivity_24h',     -- no response for 24h
    'window_closing',     -- 2h before 24h window closes
    'handoff_requested',  -- AI requests handoff
    'lead_qualified',     -- setter marks as qualified
    'keyword_match'       -- message contains a keyword
  )),
  trigger_config JSONB NOT NULL DEFAULT '{}',  -- { keywords: [], hours: 24 }
  action_type TEXT NOT NULL CHECK (action_type IN (
    'send_template',      -- send a WhatsApp template
    'assign_agent',       -- assign to specific agent
    'add_tag',            -- add a tag to conversation
    'close_conversation', -- close conversation
    'handoff_human'       -- trigger handoff to human
  )),
  action_config JSONB NOT NULL DEFAULT '{}',   -- { template_name, agent_id, tag }
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_automation_rules_workspace ON public.automation_rules(workspace_id, enabled);

CREATE TRIGGER trg_automation_rules_updated_at
  BEFORE UPDATE ON public.automation_rules
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

ALTER TABLE public.automation_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ws members read automations" ON public.automation_rules
  FOR SELECT USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "ws admins manage automations" ON public.automation_rules
  FOR ALL USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  ) WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ============ 20260609000003_agents.sql ============
-- ============================================================================
-- Agentes: named, avatar'd agents with a per-agent model + prompt.
-- 3 types per workspace (setter/soporte/agendamiento); exactly ONE active.
-- The agent's prompt reuses prompts/prompt_versions with scope='mode',
-- scope_ref=<type>; agents.prompt_id is the source of truth (no circular lookup).
-- Fully back-compatible: when no active agent / null model, runtime falls back
-- to integrations.config.model + the global prompt.
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE agent_type AS ENUM ('setter', 'soporte', 'agendamiento');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS agents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  type          agent_type NOT NULL,
  name          TEXT NOT NULL,
  avatar_key    TEXT NOT NULL DEFAULT 'default',  -- key into the curated gallery (NOT a URL)
  model         TEXT,                             -- OpenRouter id; NULL => fall back to integrations
  is_active     BOOLEAN NOT NULL DEFAULT FALSE,
  prompt_id     UUID REFERENCES prompts(id) ON DELETE SET NULL,
  config        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (workspace_id, type)
);
CREATE INDEX IF NOT EXISTS idx_agents_workspace ON agents(workspace_id);

-- Mutual exclusion: at most ONE active agent per workspace (DB-enforced).
CREATE UNIQUE INDEX IF NOT EXISTS uq_agents_one_active
  ON agents(workspace_id) WHERE is_active;

DROP TRIGGER IF EXISTS trg_agents_updated_at ON agents;
CREATE TRIGGER trg_agents_updated_at
  BEFORE UPDATE ON agents FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ---- RLS (mirror prompts: members read, admin/manager write) ----
ALTER TABLE agents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "agents_select"
  ON agents FOR SELECT
  USING (workspace_id IN (SELECT auth_workspace_ids()));

CREATE POLICY "agents_write"
  ON agents FOR ALL
  USING (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  )
  WITH CHECK (
    workspace_id IN (SELECT auth_workspace_ids())
    AND auth_has_role(workspace_id, ARRAY['admin','manager']::workspace_role[])
  );

-- ---- Atomic single-active toggle (the naive UPDATE order would violate the
--      partial unique index). Called only from the server with the service role
--      AFTER the route has verified the caller is admin/manager. ----
CREATE OR REPLACE FUNCTION set_active_agent(p_workspace UUID, p_agent UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.agents SET is_active = FALSE
    WHERE workspace_id = p_workspace AND is_active = TRUE AND id <> p_agent;
  UPDATE public.agents SET is_active = TRUE
    WHERE workspace_id = p_workspace AND id = p_agent;
END;
$$;

REVOKE ALL ON FUNCTION set_active_agent(UUID, UUID) FROM PUBLIC;
-- Supabase grants EXECUTE to anon/authenticated by default; this fn is server-only.
REVOKE EXECUTE ON FUNCTION set_active_agent(UUID, UUID) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION set_active_agent(UUID, UUID) TO service_role;

-- ============================================================================
-- Backfill: one set of 3 agents per existing workspace.
-- The setter is active and inherits the workspace's current global prompt
-- (preserving any customization) + the openrouter model. The other two get
-- inline Spanish starter prompts. Onboarding `useCase` is not persisted, so the
-- active type defaults to 'setter' (editable in the UI).
-- ============================================================================
DO $$
DECLARE
  w               RECORD;
  t               agent_type;
  v_model         TEXT;
  v_prompt        UUID;
  v_ver           UUID;
  v_body          TEXT;
  v_global_body   TEXT;
  default_names   JSONB := '{"setter":"Carlos","soporte":"Sofía","agendamiento":"Andrés"}'::jsonb;
  starters        JSONB := jsonb_build_object(
    'setter',       'Eres {{agent_name}}, agente de ventas de {{business_name}}. Tu objetivo es calificar leads y agendar citas. Sé amable, profesional y directo. Responde en mensajes cortos, como en WhatsApp.',
    'soporte',      'Eres {{agent_name}}, agente de soporte de {{business_name}}. Responde dudas con precisión y empatía. Si no puedes resolver algo, ofrece escalar con un humano. Responde en mensajes cortos.',
    'agendamiento', 'Eres {{agent_name}}, asistente de agendamiento de {{business_name}}. Ayuda a reservar citas, confirma disponibilidad y datos de contacto. Responde en mensajes cortos.'
  );
BEGIN
  FOR w IN SELECT id FROM public.workspaces LOOP
    SELECT config->>'model' INTO v_model FROM public.integrations
      WHERE workspace_id = w.id AND provider = 'openrouter' LIMIT 1;

    SELECT pv.body INTO v_global_body
      FROM public.prompts p
      JOIN public.prompt_versions pv ON pv.id = p.active_version_id
      WHERE p.workspace_id = w.id AND p.scope = 'global' LIMIT 1;

    FOREACH t IN ARRAY ARRAY['setter','soporte','agendamiento']::agent_type[] LOOP
      IF EXISTS (SELECT 1 FROM public.agents WHERE workspace_id = w.id AND type = t) THEN
        CONTINUE;
      END IF;

      v_body := COALESCE(
        CASE WHEN t = 'setter' THEN v_global_body ELSE NULL END,
        starters->>(t::text)
      );

      INSERT INTO public.prompts (workspace_id, scope, scope_ref, name)
        VALUES (w.id, 'mode', t::text, 'Agente ' || t::text)
        ON CONFLICT (workspace_id, scope, scope_ref) DO NOTHING
        RETURNING id INTO v_prompt;
      IF v_prompt IS NULL THEN
        SELECT id INTO v_prompt FROM public.prompts
          WHERE workspace_id = w.id AND scope = 'mode' AND scope_ref = t::text;
      END IF;

      INSERT INTO public.prompt_versions (workspace_id, prompt_id, version, state, body, published_at)
        VALUES (w.id, v_prompt, 1, 'published', v_body, NOW())
        ON CONFLICT (prompt_id, version) DO NOTHING
        RETURNING id INTO v_ver;
      IF v_ver IS NOT NULL THEN
        UPDATE public.prompts SET active_version_id = v_ver WHERE id = v_prompt;
      END IF;

      INSERT INTO public.agents (workspace_id, type, name, avatar_key, model, is_active, prompt_id)
        VALUES (
          w.id, t,
          default_names->>(t::text),
          t::text,                                    -- per-type default avatar
          CASE WHEN t = 'setter' THEN v_model ELSE NULL END,
          (t = 'setter'),
          v_prompt
        );
    END LOOP;
  END LOOP;
END $$;

-- ============ 20260609000004_conversation_summary.sql ============
-- Optional AI conversation summary (v1.5 backlog). Written by the auto-tagging
-- service when the active agent has config.summarize enabled.
ALTER TABLE conversations ADD COLUMN IF NOT EXISTS summary TEXT;

-- ============ 20260609000005_messages_wamid_unique.sql ============
-- Fix inbound webhook 500: processInbound upserts messages with
-- ON CONFLICT (workspace_id, wamid), but the dedup index was a PARTIAL unique
-- index (WHERE wamid IS NOT NULL), which Postgres cannot infer from a plain
-- ON CONFLICT without the predicate. Replace it with a full UNIQUE constraint.
-- NULL wamids remain allowed (NULLs are distinct), so outbound messages — which
-- have no wamid until sent — are unaffected.

drop index if exists uq_messages_wamid;

alter table public.messages
  add constraint uq_messages_wamid unique (workspace_id, wamid);

-- ============ 20260615000000_kb_match_function.sql ============
-- KB semantic search RPC.
--
-- searchKb() (src/features/inbox/services/kb-service.ts) calls this function via
-- supabase.rpc("match_kb_chunks", ...). It was missing from the schema, so KB
-- search always failed and fell back to a non-existent execute_sql RPC, making
-- the agent answer "no tengo nada registrado". This restores end-to-end KB.
--
-- Returns the top-N most similar chunks for a workspace by cosine similarity.

create or replace function match_kb_chunks(
  p_workspace_id uuid,
  p_query_embedding vector(1536),
  p_match_count int default 3
)
returns table (
  chunk_content text,
  document_title text,
  document_id uuid,
  similarity double precision
)
language sql
stable
as $$
  select
    kc.content                              as chunk_content,
    kd.title                                as document_title,
    kc.document_id                          as document_id,
    1 - (kc.embedding <=> p_query_embedding) as similarity
  from kb_chunks kc
  join kb_documents kd on kd.id = kc.document_id
  where kc.workspace_id = p_workspace_id
    and kc.embedding is not null
  order by kc.embedding <=> p_query_embedding
  limit greatest(p_match_count, 1);
$$;

-- The runtime calls this with the service role, but allow authenticated callers
-- too (RLS on kb_chunks/kb_documents still scopes rows per workspace).
grant execute on function match_kb_chunks(uuid, vector, int) to authenticated, service_role;

-- ============ 20260615000001_templates_rich_and_library.sql ============
-- Phase 4: rich WhatsApp templates (header/footer/buttons) + curated library.
--
-- The existing `templates` table only modelled a body. To replicate the ATS
-- visual builder we add header (text-only for now), footer, buttons and the
-- approval timestamps. A separate read-only `template_library` holds curated
-- starter templates that pre-fill the form (mirrors ATS's wa_template_library).

-- ── Rich fields on the workspace templates ────────────────────────────────────
alter table templates
  add column if not exists header_type text not null default 'none'
    check (header_type in ('none', 'text')),
  add column if not exists header_text text,
  add column if not exists footer_text text,
  add column if not exists buttons jsonb not null default '[]'::jsonb,
  add column if not exists submitted_at timestamptz,
  add column if not exists approved_at timestamptz;

-- ── Curated, global template library (read-only catalog) ──────────────────────
create table if not exists template_library (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  use_case text,
  category text not null
    check (category in ('marketing', 'utility', 'authentication')),
  language text not null default 'es',
  header_type text not null default 'none'
    check (header_type in ('none', 'text')),
  header_text text,
  body_template text not null,
  footer_text text,
  buttons jsonb not null default '[]'::jsonb,
  variables jsonb not null default '[]'::jsonb,
  published boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  unique (title, language)
);

alter table template_library enable row level security;

drop policy if exists "template_library_read_published" on template_library;
create policy "template_library_read_published"
  on template_library for select
  to authenticated
  using (published = true);

-- ── Seed a few common Spanish starter templates ───────────────────────────────
insert into template_library
  (title, description, use_case, category, language, body_template, footer_text, variables, sort_order)
values
  (
    'Bienvenida',
    'Saludo inicial cuando un cliente escribe por primera vez.',
    'welcome', 'utility', 'es',
    '¡Hola {{1}}! 👋 Gracias por escribir a {{2}}. ¿En qué te puedo ayudar hoy?',
    null,
    '[{"index":1,"example":"Juan"},{"index":2,"example":"Clínica Sonrisa"}]'::jsonb,
    1
  ),
  (
    'Confirmación de cita',
    'Confirma una cita agendada con fecha y hora.',
    'confirmation', 'utility', 'es',
    'Hola {{1}}, tu cita en {{2}} quedó confirmada para el {{3}}. Si necesitas reagendar, respóndenos por aquí.',
    'Gracias por tu preferencia.',
    '[{"index":1,"example":"Juan"},{"index":2,"example":"Clínica Sonrisa"},{"index":3,"example":"martes 18 a las 10:00"}]'::jsonb,
    2
  ),
  (
    'Recordatorio de cita',
    'Recordatorio el día previo a la cita.',
    'reminder', 'utility', 'es',
    'Hola {{1}}, te recordamos tu cita mañana {{2}} a las {{3}}. ¡Te esperamos! 😊',
    null,
    '[{"index":1,"example":"Juan"},{"index":2,"example":"18 de junio"},{"index":3,"example":"10:00"}]'::jsonb,
    3
  ),
  (
    'Seguimiento de interés',
    'Reactiva a un prospecto que mostró interés.',
    'follow_up', 'marketing', 'es',
    'Hola {{1}}, ¿seguimos con tu interés en {{2}}? Con gusto te ayudo a agendar una cita sin compromiso.',
    'Responde STOP para no recibir más mensajes.',
    '[{"index":1,"example":"Juan"},{"index":2,"example":"el tratamiento de blanqueamiento"}]'::jsonb,
    4
  )
on conflict (title, language) do nothing;

-- ============ 20260615000002_match_kb_search_path.sql ============
-- Harden match_kb_chunks: pin search_path (Supabase linter 0011).
-- Consistent with 20260608000008_sec02_function_hardening. The function only
-- touches public tables, so an explicit, immutable search_path is enough.

alter function match_kb_chunks(uuid, vector, int) set search_path = public, pg_temp;

-- ============ 20260615000003_enable_pg_cron_pg_net.sql ============
-- ============================================================
-- Migration: 20260615000003_enable_pg_cron_pg_net
-- Agente WhatsApp — Enable pg_cron + pg_net for the buffer-flush scheduler
--
-- The inbox "intelligent buffer" batches inbound WhatsApp messages; a worker must
-- drain them ~every minute so the agent replies as one coherent turn. Vercel Cron
-- only runs per-minute on the Pro plan (Hobby is capped at 1x/day and would fail to
-- deploy), so this distribution schedules the flush INSIDE Postgres: pg_cron fires
-- every minute and pg_net calls the app's /api/cron/buffer-flush endpoint, which runs
-- the LLM + WhatsApp send in Node (that logic cannot run inside Postgres).
--
-- This migration only ENABLES the extensions (idempotent, no secrets). Both are on
-- Supabase's allowlist and work on the free tier. The job itself is registered
-- post-deploy with the real prod URL + CRON_SECRET — see
-- supabase/cron/schedule-buffer-flush.sql.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ============================================================
-- End of migration: 20260615000003_enable_pg_cron_pg_net
-- ============================================================

-- ============ 20260617000000_harden_rls_helper_search_path.sql ============
-- ============================================================
-- Migration: 20260617000000_harden_rls_helper_search_path
-- Agente WhatsApp — fix mutable search_path in RLS helper functions
--
-- auth_workspace_ids() and auth_has_role() are SECURITY DEFINER but were created
-- WITHOUT `SET search_path` and reference `memberships` UNQUALIFIED. During RLS
-- evaluation under the `authenticated` role (whose search_path does not include
-- `public`), they fail with 42P01 'relation "memberships" does not exist'.
--
-- This only surfaces once a table HAS rows that force the policy to be evaluated
-- (workspaces / memberships / business_info / prompts / agents all get seeded
-- rows when a workspace is created), which is why getActiveWorkspace() blew up
-- and the agency "Gestionar" button bounced /settings back to /workspaces, while
-- still-empty workspace-scoped tables (conversations, messages, …) looked fine.
--
-- Fix: pin `search_path = ''` and fully-qualify public.memberships — exactly how
-- the already-correct public.is_super_admin() is written. Bodies are otherwise
-- unchanged. CREATE OR REPLACE keeps the existing REVOKE-from-anon grants.
-- ============================================================

CREATE OR REPLACE FUNCTION public.auth_workspace_ids()
RETURNS SETOF UUID
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT m.workspace_id
  FROM public.memberships m
  WHERE m.user_id = auth.uid() AND m.is_active = TRUE;
$$;

CREATE OR REPLACE FUNCTION public.auth_has_role(p_workspace UUID, p_roles public.workspace_role[])
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.memberships m
    WHERE m.user_id = auth.uid()
      AND m.workspace_id = p_workspace
      AND m.is_active = TRUE
      AND m.role = ANY(p_roles)
  );
$$;

-- ============================================================
-- End of migration: 20260617000000_harden_rls_helper_search_path
-- ============================================================

-- ============ 20260617000001_seed_check_availability_tool.sql ============
-- ============================================================
-- Migration: 20260617000001_seed_check_availability_tool
-- Agente WhatsApp — seed the missing check_availability tool
--
-- check_availability is implemented and registered in code
-- (src/features/tools/tools/check-availability.ts → registry), but it was never
-- inserted into the public.tools catalog. Since the Settings catalog reads from
-- public.tools and getEnabledTools() only returns registry tools that have an
-- enabled tool_configs row (and tool_configs FKs to tools), the tool could not
-- be shown, toggled, or offered to the agent. Seed it so it shows in the catalog
-- and can be enabled per workspace.
--
-- The schema column is for catalog/display only — the agent builds the LLM tool
-- schema from the code zod definition — but we keep it accurate for consistency.
-- Idempotent via ON CONFLICT, matching the original tools seed.
-- ============================================================

INSERT INTO public.tools (key, name, description, schema, sensitivity) VALUES
  ('check_availability', 'Consultar disponibilidad',
   'Checks real free time slots from the HighLevel calendar for a date range',
   '{"type":"object","properties":{"date_from":{"type":"string"},"date_to":{"type":"string"},"timezone":{"type":"string"},"calendar_id":{"type":"string"}},"required":["date_from","date_to"]}',
   'read')
ON CONFLICT (key) DO UPDATE
  SET name = EXCLUDED.name,
      description = EXCLUDED.description,
      schema = EXCLUDED.schema,
      sensitivity = EXCLUDED.sensitivity;

-- ============================================================
-- End of migration: 20260617000001_seed_check_availability_tool
-- ============================================================

-- ============ 20260617000002_add_processing_to_batch_status.sql ============
-- ============================================================
-- Migration: 20260617000002_add_processing_to_batch_status
-- Agente WhatsApp — add the missing 'processing' value to batch_status
--
-- batch_status was created as ('buffering','flushed','processed','cancelled'),
-- but claim_next_batch() and cancel_batch() set and match status = 'processing'.
-- plpgsql casts the enum literal at RUNTIME, so the original migration applied
-- cleanly, yet every claim_next_batch() call threw:
--   invalid input value for enum batch_status: "processing"
-- processNextBatch() swallowed that as a failed claim and returned
-- {processed:false}, so the cron drained nothing — buffered inbound messages
-- were never processed and the AI never replied.
--
-- Add the missing value. (ADD VALUE appends to the end; enum position does not
-- affect the equality/IN comparisons claim_next_batch uses.)
-- ============================================================

ALTER TYPE public.batch_status ADD VALUE IF NOT EXISTS 'processing';

-- ============================================================
-- End of migration: 20260617000002_add_processing_to_batch_status
-- ============================================================

