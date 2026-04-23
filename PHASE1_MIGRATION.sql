-- ═══════════════════════════════════════════════════════════════════════
-- CIRCLE SOLUTIONS — PHASE 1 MIGRATION
-- ═══════════════════════════════════════════════════════════════════════
-- Adds: team_lead role, markets, reports_to hierarchy, avatars
--
-- HOW TO RUN:
--   1. Supabase dashboard → SQL Editor → New query
--   2. Paste this entire file
--   3. Click Run
--   4. You should see "Success. No rows returned."
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. Update profiles: add team_lead role + hierarchy fields + avatar
-- ───────────────────────────────────────────────────────────────────────

-- Drop old role check constraint, add new one with team_lead
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('owner','admin','manager','team_lead','agent'));

-- Add columns if they don't exist
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS reports_to UUID REFERENCES public.profiles(id) ON DELETE SET NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS market_id UUID;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;


-- ───────────────────────────────────────────────────────────────────────
-- 2. Markets table — owner-managed, scoped to program
-- ───────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.markets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id TEXT NOT NULL REFERENCES public.programs(id),
  name TEXT NOT NULL,
  city TEXT,
  state TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_markets_program ON public.markets(program_id);

-- Add FK constraint on profiles.market_id now that markets exists
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'profiles_market_id_fkey') THEN
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_market_id_fkey
      FOREIGN KEY (market_id) REFERENCES public.markets(id) ON DELETE SET NULL;
  END IF;
END $$;

-- Enable RLS on markets
ALTER TABLE public.markets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "markets_select" ON public.markets;
CREATE POLICY "markets_select" ON public.markets FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Only owners can create/modify/delete markets
DROP POLICY IF EXISTS "markets_owner_modify" ON public.markets;
CREATE POLICY "markets_owner_modify" ON public.markets FOR ALL
  USING (public.current_role() = 'owner')
  WITH CHECK (public.current_role() = 'owner');


-- ───────────────────────────────────────────────────────────────────────
-- 3. Tighten profile RLS — owner-only for sensitive operations
-- ───────────────────────────────────────────────────────────────────────

-- Drop existing broad admin policies, replace with owner-gated ones
DROP POLICY IF EXISTS "profiles_insert_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_delete_admin" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;

-- Only owner can delete profiles (never managers)
CREATE POLICY "profiles_delete_owner" ON public.profiles FOR DELETE
  USING (public.current_role() = 'owner');

-- Owners and admins can insert profiles; managers can insert profiles for their programs
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT
  WITH CHECK (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND programs <@ public.current_programs() -- new profile's programs must all be within mgr's programs
    )
  );

-- Updates: owner/admin can update anyone; manager can update agents/team_leads in their programs (but NOT other managers/admins/owners)
CREATE POLICY "profiles_update_admin" ON public.profiles FOR UPDATE
  USING (
    public.current_role() IN ('owner','admin')
    OR (
      public.current_role() = 'manager'
      AND role IN ('agent','team_lead')
      AND programs && public.current_programs()
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 4. Storage bucket for avatars (run manually via Supabase dashboard if this fails)
-- ───────────────────────────────────────────────────────────────────────
-- Supabase Storage buckets can't always be created via SQL alone.
-- If this block errors, create it manually:
--   Supabase dashboard → Storage → New bucket → name: "avatars" → Public bucket: YES → Save
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for avatars
DROP POLICY IF EXISTS "avatar_public_read" ON storage.objects;
CREATE POLICY "avatar_public_read" ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatar_auth_upload" ON storage.objects;
CREATE POLICY "avatar_auth_upload" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "avatar_auth_update" ON storage.objects;
CREATE POLICY "avatar_auth_update" ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
  );

DROP POLICY IF EXISTS "avatar_auth_delete" ON storage.objects;
CREATE POLICY "avatar_auth_delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars'
    AND auth.uid() IS NOT NULL
  );


-- ═══════════════════════════════════════════════════════════════════════
-- DONE — Phase 1 database changes applied.
-- ═══════════════════════════════════════════════════════════════════════
