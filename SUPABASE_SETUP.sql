-- ═══════════════════════════════════════════════════════════════════════
-- CIRCLE SOLUTIONS INC. — SUPABASE DATABASE SETUP
-- ═══════════════════════════════════════════════════════════════════════
-- HOW TO USE:
--   1. Open your Supabase project dashboard (supabase.com)
--   2. Left sidebar → "SQL Editor" → "New query"
--   3. Paste this ENTIRE file
--   4. Click "Run" (bottom right)
--   5. Wait ~10 seconds. You should see "Success. No rows returned."
--
-- If you ever need to reset everything, run the DROP statements at the
-- bottom of this file (commented out) first, then run the whole thing again.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. PROGRAMS TABLE — the 3 back offices
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.programs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT,
  icon TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO public.programs (id, name, description, color, icon) VALUES
  ('retail', 'Residential Retail Energy', 'In-store kiosks at Walmart, Sam''s Club, Kroger and other major retailers', '#FF6B00', '⚡'),
  ('b2b', 'Business-to-Business Energy', 'Commercial energy acquisition — small business to enterprise accounts', '#0080FF', '🏢'),
  ('fiber', 'Fiber Internet', 'Door-to-door subscriber acquisition for major fiber ISPs', '#00C6FF', '🌐')
ON CONFLICT (id) DO NOTHING;


-- ───────────────────────────────────────────────────────────────────────
-- 2. PROFILES TABLE — extends Supabase's built-in auth.users
-- ───────────────────────────────────────────────────────────────────────
-- Every user who signs up gets a row here automatically (via trigger below).
-- role: 'owner' | 'admin' | 'manager' | 'agent'
-- programs: array of program IDs the user has access to, e.g. {'retail','b2b'}
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  full_name TEXT,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'agent' CHECK (role IN ('owner','admin','manager','agent')),
  programs TEXT[] DEFAULT '{}',
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile when a new auth user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, programs)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'agent'),
    COALESCE(
      (SELECT ARRAY(SELECT jsonb_array_elements_text(NEW.raw_user_meta_data->'programs'))),
      '{}'::TEXT[]
    )
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ───────────────────────────────────────────────────────────────────────
-- 3. AGENT CODES — unique per agent, per program
-- ───────────────────────────────────────────────────────────────────────
-- Stores each agent's unique IDs / portal credentials for each program
-- they're assigned to. Only the agent themselves + managers/owners of
-- their program can see these.
CREATE TABLE IF NOT EXISTS public.agent_codes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  program_id TEXT NOT NULL REFERENCES public.programs(id),
  label TEXT NOT NULL,
  value TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_agent_codes_user ON public.agent_codes(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_codes_program ON public.agent_codes(program_id);


-- ───────────────────────────────────────────────────────────────────────
-- 4. ANNOUNCEMENTS — scoped to program
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id TEXT REFERENCES public.programs(id),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  posted_by UUID REFERENCES public.profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_announcements_program ON public.announcements(program_id);


-- ───────────────────────────────────────────────────────────────────────
-- 5. TRAINING DOCS — scoped to program
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.training_docs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id TEXT NOT NULL REFERENCES public.programs(id),
  title TEXT NOT NULL,
  description TEXT,
  body TEXT,
  url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_training_program ON public.training_docs(program_id);


-- ───────────────────────────────────────────────────────────────────────
-- 6. CONTRACTS — onboarding paperwork per agent per program
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.contracts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  program_id TEXT NOT NULL REFERENCES public.programs(id),
  title TEXT NOT NULL,
  url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending','signed','expired')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_contracts_user ON public.contracts(user_id);


-- ───────────────────────────────────────────────────────────────────────
-- 7. ENROLLMENTS — for dashboard numbers + leaderboards
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  program_id TEXT NOT NULL REFERENCES public.programs(id),
  customer_name TEXT,
  customer_location TEXT,
  notes TEXT,
  enrollment_date DATE DEFAULT CURRENT_DATE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active','pending','cancelled')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_enrollments_user ON public.enrollments(user_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_program ON public.enrollments(program_id);


-- ───────────────────────────────────────────────────────────────────────
-- 8. APPLICATIONS — from public career apply form
-- ───────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed BOOLEAN DEFAULT FALSE
);


-- ═══════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY — the heart of the access control
-- ═══════════════════════════════════════════════════════════════════════
-- Every table has RLS enabled. Policies below control exactly who can
-- read/write what based on their role and assigned programs.
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE public.profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.programs       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.agent_codes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.training_docs  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contracts      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.applications   ENABLE ROW LEVEL SECURITY;


-- ─── Helper: get current user's role ───
CREATE OR REPLACE FUNCTION public.current_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ─── Helper: get current user's programs ───
CREATE OR REPLACE FUNCTION public.current_programs()
RETURNS TEXT[] AS $$
  SELECT programs FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;


-- ─── Profiles policies ───
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT
  USING (
    auth.uid() = id -- users can always see their own profile
    OR public.current_role() IN ('owner','admin') -- owners/admins see all
    OR (
      public.current_role() = 'manager'
      AND programs && public.current_programs() -- managers see profiles sharing any program
    )
  );

DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
CREATE POLICY "profiles_update_self" ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND role = (SELECT role FROM public.profiles WHERE id = auth.uid()));

DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;
CREATE POLICY "profiles_update_admin" ON public.profiles FOR UPDATE
  USING (public.current_role() IN ('owner','admin'));

DROP POLICY IF EXISTS "profiles_insert_admin" ON public.profiles;
CREATE POLICY "profiles_insert_admin" ON public.profiles FOR INSERT
  WITH CHECK (public.current_role() IN ('owner','admin'));

DROP POLICY IF EXISTS "profiles_delete_admin" ON public.profiles;
CREATE POLICY "profiles_delete_admin" ON public.profiles FOR DELETE
  USING (public.current_role() IN ('owner','admin'));


-- ─── Programs policies (read-only for everyone signed in) ───
DROP POLICY IF EXISTS "programs_select_all" ON public.programs;
CREATE POLICY "programs_select_all" ON public.programs FOR SELECT
  USING (auth.uid() IS NOT NULL);


-- ─── Agent codes policies ───
-- Each user sees their own codes + managers/owners see codes for their programs
DROP POLICY IF EXISTS "codes_select" ON public.agent_codes;
CREATE POLICY "codes_select" ON public.agent_codes FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );

DROP POLICY IF EXISTS "codes_modify" ON public.agent_codes;
CREATE POLICY "codes_modify" ON public.agent_codes FOR ALL
  USING (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  )
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );


-- ─── Announcements policies ───
-- Everyone in a program sees its announcements; only managers+ post
DROP POLICY IF EXISTS "announcements_select" ON public.announcements;
CREATE POLICY "announcements_select" ON public.announcements FOR SELECT
  USING (
    program_id IS NULL -- company-wide
    OR program_id = ANY(public.current_programs())
    OR public.current_role() IN ('owner','admin')
  );

DROP POLICY IF EXISTS "announcements_modify" ON public.announcements;
CREATE POLICY "announcements_modify" ON public.announcements FOR ALL
  USING (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  )
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );


-- ─── Training docs policies ───
DROP POLICY IF EXISTS "training_select" ON public.training_docs;
CREATE POLICY "training_select" ON public.training_docs FOR SELECT
  USING (
    program_id = ANY(public.current_programs())
    OR public.current_role() IN ('owner','admin')
  );

DROP POLICY IF EXISTS "training_modify" ON public.training_docs;
CREATE POLICY "training_modify" ON public.training_docs FOR ALL
  USING (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  )
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );


-- ─── Contracts policies ───
DROP POLICY IF EXISTS "contracts_select" ON public.contracts;
CREATE POLICY "contracts_select" ON public.contracts FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );

DROP POLICY IF EXISTS "contracts_modify" ON public.contracts;
CREATE POLICY "contracts_modify" ON public.contracts FOR ALL
  USING (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  )
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );


-- ─── Enrollments policies ───
DROP POLICY IF EXISTS "enrollments_select" ON public.enrollments;
CREATE POLICY "enrollments_select" ON public.enrollments FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );

DROP POLICY IF EXISTS "enrollments_insert" ON public.enrollments;
CREATE POLICY "enrollments_insert" ON public.enrollments FOR INSERT
  WITH CHECK (
    (user_id = auth.uid() AND program_id = ANY(public.current_programs()))
    OR public.current_role() IN ('owner','admin','manager')
  );

DROP POLICY IF EXISTS "enrollments_modify" ON public.enrollments;
CREATE POLICY "enrollments_modify" ON public.enrollments FOR UPDATE
  USING (
    user_id = auth.uid()
    OR public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );

DROP POLICY IF EXISTS "enrollments_delete" ON public.enrollments;
CREATE POLICY "enrollments_delete" ON public.enrollments FOR DELETE
  USING (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND program_id = ANY(public.current_programs())
    )
  );


-- ─── Applications policies ───
-- Anyone (including anonymous applicants) can INSERT; only admins read/modify
DROP POLICY IF EXISTS "applications_insert_public" ON public.applications;
CREATE POLICY "applications_insert_public" ON public.applications FOR INSERT
  WITH CHECK (TRUE);

DROP POLICY IF EXISTS "applications_select_admin" ON public.applications;
CREATE POLICY "applications_select_admin" ON public.applications FOR SELECT
  USING (public.current_role() IN ('owner','admin'));

DROP POLICY IF EXISTS "applications_modify_admin" ON public.applications;
CREATE POLICY "applications_modify_admin" ON public.applications FOR ALL
  USING (public.current_role() IN ('owner','admin'));


-- ═══════════════════════════════════════════════════════════════════════
-- DONE. After running this:
-- ═══════════════════════════════════════════════════════════════════════
-- 1. Go to Authentication → Providers → Email
--    Turn OFF "Confirm email" (so agents can log in immediately with the
--    password you create for them, without clicking a confirmation link)
--
-- 2. Create your owner account:
--    Authentication → Users → "Add user" → "Create new user"
--    Email: youremail@example.com
--    Password: (pick a strong one, save it)
--    Check "Auto Confirm User"
--    Click "Create user"
--
-- 3. Promote that user to owner role:
--    SQL Editor → New query → paste this (replace the email):
--
--    UPDATE public.profiles
--    SET role = 'owner', programs = ARRAY['retail','b2b','fiber']
--    WHERE email = 'youremail@example.com';
--
-- 4. Deploy your site — you're done!
-- ═══════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════
-- DANGER ZONE — uncomment and run to reset everything
-- ═══════════════════════════════════════════════════════════════════════
-- DROP TABLE IF EXISTS public.applications CASCADE;
-- DROP TABLE IF EXISTS public.enrollments CASCADE;
-- DROP TABLE IF EXISTS public.contracts CASCADE;
-- DROP TABLE IF EXISTS public.training_docs CASCADE;
-- DROP TABLE IF EXISTS public.announcements CASCADE;
-- DROP TABLE IF EXISTS public.agent_codes CASCADE;
-- DROP TABLE IF EXISTS public.profiles CASCADE;
-- DROP TABLE IF EXISTS public.programs CASCADE;
-- DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
-- DROP FUNCTION IF EXISTS public.current_role() CASCADE;
-- DROP FUNCTION IF EXISTS public.current_programs() CASCADE;
