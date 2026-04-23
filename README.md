# Circle Solutions Inc. — Phase 1 Update

## What's new in this version

- 5-role hierarchy: **Owner / Admin / Manager / Team Lead / Agent**
- **Markets** system (add Dallas, San Antonio, etc. per program)
- **Reports To** field — link agents to their team lead or manager
- **Profile pictures** (upload avatars, max 2MB)
- **👑 Owner Panel** — locked from everyone except you
- **Delete team members** (owner only, type DELETE to confirm)
- **Password reset** button per user (owner only — sends Supabase reset email)
- **Visibility fixed** — managers no longer see owner-only tools
- **Search bar** in team list to find people by name/email

## Upgrade steps

If you already ran `SUPABASE_SETUP.sql` previously, you only need to:

### 1. Run the migration SQL

- Supabase dashboard → SQL Editor → New query
- Open `PHASE1_MIGRATION.sql` → copy-paste all → Run
- Should see "Success. No rows returned."

### 2. Verify the avatars storage bucket

- Supabase → **Storage** (left sidebar)
- You should see a bucket called **`avatars`**
- If not, click **New bucket** → name: `avatars` → **Public bucket: ON** → Create

### 3. Push new `index.html` to GitHub

- Go to github.com/CSI2026/circlesolutionsinc.com
- Click `index.html` → pencil icon → delete all content → paste the new one
- Commit directly to `main`
- Wait 1-2 min for GitHub Pages to redeploy

### 4. Upload the new SQL files to GitHub (for your records)

- Repo root → Add file → Upload files
- Drag in `PHASE1_MIGRATION.sql` and the updated `README.md`
- Commit

## Test checklist after upgrading

1. ✅ Log in at circlesolutionsinc.com with your owner account
2. ✅ You should land on the **👑 Owner Panel** (new!)
3. ✅ Click **📍 Markets** → add a test market (e.g. "Dallas TX" under Fiber)
4. ✅ Click **👥 Team** → click Edit on any agent → you should see new fields for Market + Reports To
5. ✅ Log in as Baron in an incognito window — he should NOT see Owner Panel, Markets, Applications, or Programs nav items
6. ✅ Upload a profile picture on your Account → My Profile page

## Coming next

- **Phase 2:** documents & folders, form builder, training call links, announcements per program, contract automation, "email login" button
- **Phase 3:** Jitsi video training rooms, group chat, SMS notifications, workflow automations

© 2025 Circle Solutions Inc.
