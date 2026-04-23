# Circle Solutions Inc. — Phase 2 Update

## What's new in this version

### Training Calls (Jitsi video with waiting room)
- Managers/admins with `can_host_meetings` permission can schedule training calls
- **Built-in Jitsi video** (free, no account needed) — runs inside your back office
- Waiting room: non-hosts wait until the host starts the meeting
- **Auto-admit when host joins** — everyone waiting drops straight into the call
- Optional recording toggle per meeting
- Also supports external links (Zoom, Meet, Teams) as fallback
- Email invites sent to all program members automatically

### Documents Library
- **Company Library** (global) — visible to everyone, owner/admin upload
- **Per-program Documents** — each program has its own document area
- Folders + files, uploads up to 25MB per file
- Files stored privately in Supabase Storage, signed download URLs

### Contract Templates (Owner only)
- Define default contracts per program (e.g. "NDA", "ICA", "W9")
- When a new agent is created in that program, the templates auto-assign to their contracts list
- Link to Google Drive, DocuSign, Dropbox — whatever you use

### Form Builder
- Owner/admins build custom forms (timesheets, incident reports, surveys, etc.)
- Field types: text, long text, number, date, dropdown, checkbox
- Per-program or global scope
- Agents fill out from the "📋 My Forms" sidebar or program Forms tab
- View submissions inline or export to CSV

### Scoped Announcements
- Post to: Company-wide / Program / Market / Your Direct Team
- Optional "Also send as email" broadcast to all recipients

### Email Automation (via Resend)
- Hidden API key, server-side Edge Function
- Auto-sends welcome email with login details when you create a new team member
- "📧 Email Login" button in team list for re-sending
- Meeting invites, announcements, contract-assigned notifications
- All emails from `noreply@circlesolutionsinc.com` (your verified domain)

### Host Permission Toggle
- Owner sets `🎥 Can host training calls` on each team member
- Default OFF — only owner/admin can host unless you grant it
- Found in the Edit Team Member modal (owner-only)

---

## Upgrade steps (do these in order)

### 1. Run the Phase 2 SQL migration

Supabase dashboard → SQL Editor → New query → paste `PHASE2_MIGRATION.sql` → Run.
You should see "Success. No rows returned."

### 2. Deploy the `send-email` Edge Function

See `EDGE_FUNCTION_SETUP.md` for the full guide. Short version:

1. Supabase dashboard → Edge Functions → Create new function → name it `send-email`
2. Paste the contents of `supabase-edge-functions/send-email/index.ts`
3. Deploy
4. Supabase dashboard → Project Settings → Edge Functions → Secrets → add `RESEND_API_KEY` = your new Resend API key

### 3. Verify the `documents` storage bucket

Supabase → Storage → should see a `documents` bucket (private, NOT public — that's correct).

### 4. Push updated `index.html` to GitHub

github.com/CSI2026/circlesolutionsinc.com → edit `index.html` → paste new content → commit to `main`.

Also upload `PHASE2_MIGRATION.sql`, `EDGE_FUNCTION_SETUP.md`, and the `supabase-edge-functions/send-email/index.ts` file to the repo for your records.

### 5. Test it

1. Log in at https://circlesolutionsinc.com as owner
2. Go to 👥 Team → click a team member → Edit → check the **🎥 Can host training calls** toggle for anyone you want able to schedule meetings
3. Click into a program → 📞 Training Calls tab → "+ Schedule Call" → create a test meeting for 5 minutes from now
4. Have a teammate log in — they'll see it listed. Click Join → waiting room.
5. As host, click "Start Meeting" → teammate gets auto-admitted.
6. Test documents: Click 📁 Company Library → create a folder → upload a file → make sure non-admin users can see it.
7. Test forms: 📋 All Forms → "+ Create Form" → add a few fields → save. Then log in as a non-admin and see it under "📋 My Forms".
8. Create a new test team member — they should receive the welcome email automatically.

---

## File manifest

```
index.html                                    ← new version, replaces your existing file
PHASE2_MIGRATION.sql                          ← run in Supabase SQL editor
EDGE_FUNCTION_SETUP.md                        ← step-by-step edge function deploy
supabase-edge-functions/send-email/index.ts   ← edge function source code
SUPABASE_SETUP.sql                            ← original schema (unchanged, for reference)
PHASE1_MIGRATION.sql                          ← previous migration (unchanged)
README.md                                     ← this file
404.html                                      ← unchanged
```

---

## Known limitations (things for later)

- **Signup quirk preserved**: when you create a new agent client-side, Supabase briefly signs you in as them. We detect this and sign you out with a warning. The proper fix is to create users through a server-side Edge Function using the service-role key — documented as future work.
- **Group chat / DMs**: not yet. Planned for Phase 3.
- **SMS notifications** (Twilio): not yet. Planned for Phase 3.
- **Self-hosted Jitsi** with custom branding: using meet.jit.si (free public instance) for now — works great, but you could self-host later to remove the "jit.si" branding.
- **Jitsi recording**: requires you to link a Dropbox account to meet.jit.si (it's free — users will see a prompt). Alternative is self-hosted Jitsi with local file storage.

---

## Support

Questions or issues? Contact info@circlesolutionsinc.com.
