-- ═══════════════════════════════════════════════════════════════════════
-- CIRCLE SOLUTIONS — PHASE 2 MIGRATION
-- ═══════════════════════════════════════════════════════════════════════
-- Adds: Documents, Training Calls/Meetings with Jitsi + Waiting Room,
--       Scoped Announcements, Contract Templates, Form Builder, Email hooks
--
-- HOW TO RUN:
--   1. Supabase dashboard → SQL Editor → New query
--   2. Paste this entire file
--   3. Click Run
--   4. You should see "Success. No rows returned."
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. Add can_host_meetings to profiles (default OFF)
-- ───────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS can_host_meetings BOOLEAN DEFAULT FALSE;


-- ───────────────────────────────────────────────────────────────────────
-- 2. DOCUMENT FOLDERS (global + per-program)
-- ───────────────────────────────────────────────────────────────────────
-- program_id NULL = global/company-wide folder
CREATE TABLE IF NOT EXISTS public.document_folders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id TEXT REFERENCES public.programs(id) ON DELETE CASCADE,
  parent_id UUID REFERENCES public.document_folders(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_folders_program ON public.document_folders(program_id);
CREATE INDEX IF NOT EXISTS idx_folders_parent ON public.document_folders(parent_id);


-- ───────────────────────────────────────────────────────────────────────
-- 3. DOCUMENTS (files in folders)
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  folder_id UUID REFERENCES public.document_folders(id) ON DELETE CASCADE,
  program_id TEXT REFERENCES public.programs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_path TEXT NOT NULL,
  size_bytes BIGINT,
  mime_type TEXT,
  uploaded_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_docs_folder ON public.documents(folder_id);
CREATE INDEX IF NOT EXISTS idx_docs_program ON public.documents(program_id);


-- ───────────────────────────────────────────────────────────────────────
-- 4. MEETINGS (training calls — Jitsi or external links)
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.meetings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id TEXT NOT NULL REFERENCES public.programs(id),
  title TEXT NOT NULL,
  description TEXT,
  host_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  platform TEXT NOT NULL DEFAULT 'jitsi' CHECK (platform IN ('jitsi','zoom','meet','teams','other')),
  meeting_url TEXT,
  jitsi_room TEXT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_min INTEGER DEFAULT 60,
  recording_enabled BOOLEAN DEFAULT FALSE,
  recording_url TEXT,
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled','live','ended','cancelled')),
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_meetings_program ON public.meetings(program_id);
CREATE INDEX IF NOT EXISTS idx_meetings_scheduled ON public.meetings(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_meetings_status ON public.meetings(status);


-- ───────────────────────────────────────────────────────────────────────
-- 5. MEETING PARTICIPANTS (waiting room tracking)
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.meeting_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  meeting_id UUID NOT NULL REFERENCES public.meetings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'waiting' CHECK (status IN ('waiting','admitted','denied','left')),
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  admitted_at TIMESTAMPTZ,
  UNIQUE(meeting_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_participants_meeting ON public.meeting_participants(meeting_id);
CREATE INDEX IF NOT EXISTS idx_participants_status ON public.meeting_participants(status);


-- ───────────────────────────────────────────────────────────────────────
-- 6. CONTRACT TEMPLATES (auto-assigned to new agents per program)
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contract_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id TEXT NOT NULL REFERENCES public.programs(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  url TEXT,
  required BOOLEAN DEFAULT TRUE,
  auto_assign BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);


-- ───────────────────────────────────────────────────────────────────────
-- 7. FORMS + SUBMISSIONS
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.forms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  program_id TEXT REFERENCES public.programs(id) ON DELETE CASCADE,
  fields JSONB NOT NULL DEFAULT '[]'::jsonb,
  active BOOLEAN DEFAULT TRUE,
  created_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.form_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id UUID NOT NULL REFERENCES public.forms(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  data JSONB NOT NULL,
  submitted_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_submissions_form ON public.form_submissions(form_id);
CREATE INDEX IF NOT EXISTS idx_submissions_user ON public.form_submissions(user_id);


-- ───────────────────────────────────────────────────────────────────────
-- 8. Upgrade announcements — add scope fields
-- ───────────────────────────────────────────────────────────────────────
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'program' CHECK (scope IN ('company','program','team','market'));
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS market_id UUID REFERENCES public.markets(id) ON DELETE SET NULL;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS team_of UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.announcements ADD COLUMN IF NOT EXISTS recognition_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;


-- ═══════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE public.document_folders     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.documents            ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meetings             ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meeting_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contract_templates   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.forms                ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.form_submissions     ENABLE ROW LEVEL SECURITY;


-- ─── Document folders ───
-- Readable: global folders by anyone signed in; program folders by program members + admins/owner
DROP POLICY IF EXISTS "folders_select" ON public.document_folders;
CREATE POLICY "folders_select" ON public.document_folders FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND (
      program_id IS NULL  -- global
      OR program_id = ANY(public.current_programs())
      OR public.current_role() IN ('owner','admin')
    )
  );

-- Modify: managers within their programs; owners/admins anywhere
DROP POLICY IF EXISTS "folders_modify" ON public.document_folders;
CREATE POLICY "folders_modify" ON public.document_folders FOR ALL
  USING (
    public.current_role() IN ('owner','admin')
    OR (public.current_role() = 'manager' AND program_id = ANY(public.current_programs()))
  )
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (public.current_role() = 'manager' AND program_id = ANY(public.current_programs()))
  );


-- ─── Documents ───
DROP POLICY IF EXISTS "documents_select" ON public.documents;
CREATE POLICY "documents_select" ON public.documents FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND (
      program_id IS NULL
      OR program_id = ANY(public.current_programs())
      OR public.current_role() IN ('owner','admin')
    )
  );

DROP POLICY IF EXISTS "documents_insert" ON public.documents;
CREATE POLICY "documents_insert" ON public.documents FOR INSERT
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (public.current_role() = 'manager' AND program_id = ANY(public.current_programs()))
  );

DROP POLICY IF EXISTS "documents_delete" ON public.documents;
CREATE POLICY "documents_delete" ON public.documents FOR DELETE
  USING (
    public.current_role() = 'owner'
    OR (public.current_role() IN ('admin','manager') AND uploaded_by = auth.uid())
  );


-- ─── Meetings ───
DROP POLICY IF EXISTS "meetings_select" ON public.meetings;
CREATE POLICY "meetings_select" ON public.meetings FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND (
      program_id = ANY(public.current_programs())
      OR public.current_role() IN ('owner','admin')
    )
  );

-- Only users with can_host_meetings (or owner/admin) can create/modify meetings
DROP POLICY IF EXISTS "meetings_modify" ON public.meetings;
CREATE POLICY "meetings_modify" ON public.meetings FOR ALL
  USING (
    public.current_role() = 'owner'
    OR (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (can_host_meetings = TRUE OR role IN ('owner','admin')))
      AND program_id = ANY(public.current_programs())
    )
  )
  WITH CHECK (
    public.current_role() = 'owner'
    OR (
      EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (can_host_meetings = TRUE OR role IN ('owner','admin')))
      AND program_id = ANY(public.current_programs())
    )
  );


-- ─── Meeting participants (waiting room) ───
DROP POLICY IF EXISTS "participants_select" ON public.meeting_participants;
CREATE POLICY "participants_select" ON public.meeting_participants FOR SELECT
  USING (
    auth.uid() IS NOT NULL  -- anyone signed in can see waiting-room state (filtered client-side)
  );

DROP POLICY IF EXISTS "participants_insert" ON public.meeting_participants;
CREATE POLICY "participants_insert" ON public.meeting_participants FOR INSERT
  WITH CHECK (user_id = auth.uid());  -- users can only add themselves

DROP POLICY IF EXISTS "participants_update" ON public.meeting_participants;
CREATE POLICY "participants_update" ON public.meeting_participants FOR UPDATE
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.meetings m WHERE m.id = meeting_id AND (m.host_id = auth.uid() OR public.current_role() IN ('owner','admin')))
  );


-- ─── Contract templates ───
DROP POLICY IF EXISTS "templates_select" ON public.contract_templates;
CREATE POLICY "templates_select" ON public.contract_templates FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "templates_modify" ON public.contract_templates;
CREATE POLICY "templates_modify" ON public.contract_templates FOR ALL
  USING (public.current_role() = 'owner')
  WITH CHECK (public.current_role() = 'owner');


-- ─── Forms ───
DROP POLICY IF EXISTS "forms_select" ON public.forms;
CREATE POLICY "forms_select" ON public.forms FOR SELECT
  USING (
    auth.uid() IS NOT NULL AND active = TRUE AND (
      program_id IS NULL
      OR program_id = ANY(public.current_programs())
      OR public.current_role() IN ('owner','admin')
    )
  );

DROP POLICY IF EXISTS "forms_modify" ON public.forms;
CREATE POLICY "forms_modify" ON public.forms FOR ALL
  USING (
    public.current_role() IN ('owner','admin')
    OR (public.current_role() = 'manager' AND program_id = ANY(public.current_programs()))
  )
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (public.current_role() = 'manager' AND program_id = ANY(public.current_programs()))
  );


-- ─── Form submissions ───
DROP POLICY IF EXISTS "submissions_select" ON public.form_submissions;
CREATE POLICY "submissions_select" ON public.form_submissions FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.current_role() IN ('owner','admin')
    OR EXISTS (
      SELECT 1 FROM public.forms f
      WHERE f.id = form_id
        AND (public.current_role() = 'manager' AND f.program_id = ANY(public.current_programs()))
    )
  );

DROP POLICY IF EXISTS "submissions_insert" ON public.form_submissions;
CREATE POLICY "submissions_insert" ON public.form_submissions FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);


-- ═══════════════════════════════════════════════════════════════════════
-- STORAGE: documents bucket (private, authenticated access)
-- ═══════════════════════════════════════════════════════════════════════
INSERT INTO storage.buckets (id, name, public)
VALUES ('documents', 'documents', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "docs_select_auth" ON storage.objects;
CREATE POLICY "docs_select_auth" ON storage.objects FOR SELECT
  USING (bucket_id = 'documents' AND auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "docs_insert_auth" ON storage.objects;
CREATE POLICY "docs_insert_auth" ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'documents' AND auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "docs_delete_auth" ON storage.objects;
CREATE POLICY "docs_delete_auth" ON storage.objects FOR DELETE
  USING (bucket_id = 'documents' AND auth.uid() IS NOT NULL);


-- ═══════════════════════════════════════════════════════════════════════
-- DONE — Phase 2 schema applied.
-- ═══════════════════════════════════════════════════════════════════════
-- After running this:
-- 1. Check Storage → you should see a new "documents" bucket (private)
-- 2. Deploy the send-email Edge Function (see EDGE_FUNCTION_SETUP.md)
-- 3. Add RESEND_API_KEY as a secret in Supabase dashboard → Settings → Edge Functions → Secrets
-- ═══════════════════════════════════════════════════════════════════════
