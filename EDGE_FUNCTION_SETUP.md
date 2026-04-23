# Edge Function Setup — `send-email`

This Edge Function sends transactional emails via Resend. It keeps your API key hidden server-side (never in the browser).

## Quick path — deploy via Supabase Dashboard (no CLI needed)

### Step 1: Create the function in Supabase

1. Go to your Supabase project → **Edge Functions** (left sidebar)
2. Click **"Create a new function"** (or "Deploy a new function")
3. Function name: `send-email` (exactly this, lowercase with hyphen)
4. If Supabase gives you a code editor right there, paste the contents of `supabase-edge-functions/send-email/index.ts` into it and click Deploy.
5. If it asks you to use CLI, see the CLI path below.

### Step 2: Add the Resend API key as a secret

1. Supabase dashboard → **Project Settings** (gear icon, bottom left) → **Edge Functions** → **Secrets** tab
2. Click **"New secret"**
3. Name: `RESEND_API_KEY`
4. Value: paste your Resend API key (the new one, starts with `re_...`)
5. Save

### Step 3: Test it

1. Back in Edge Functions → click on `send-email` → **Invoke** tab
2. Paste this as the body:
   ```json
   {
     "template": "welcome",
     "to": "your@email.com",
     "variables": {
       "full_name": "Test User",
       "email": "test@example.com",
       "password": "testpass123",
       "role_label": "Agent",
       "programs": ["Fiber"]
     }
   }
   ```
3. Click **Run** — you should get `{"success": true, "id": "..."}` and an email in your inbox within 30 seconds.

---

## Alternative path — deploy via CLI (for developers)

If you have the Supabase CLI installed:

```bash
# Install CLI if you don't have it
npm install -g supabase

# Log in
supabase login

# Link to your project (run this in your repo folder)
supabase link --project-ref liqsqsocwjfqiupmehpn

# Set the secret
supabase secrets set RESEND_API_KEY=re_your_key_here

# Deploy the function
supabase functions deploy send-email --no-verify-jwt
```

(The `--no-verify-jwt` flag is because we're calling from authenticated browser sessions — Supabase's gateway already validates the user's JWT.)

---

## Troubleshooting

**"RESEND_API_KEY not configured"**
→ You didn't add the secret, or you spelled the name differently. Make sure it's exactly `RESEND_API_KEY`.

**"Domain not verified"**
→ Check Resend → Domains → `circlesolutionsinc.com` should show all 4 records ✅ verified.

**Email went to spam**
→ Normal for the first few emails. Have recipients mark as "Not Spam" and add `noreply@circlesolutionsinc.com` to their contacts. After ~20 successful deliveries, Gmail/Outlook will trust the domain.

**Want to check what was sent?**
→ Resend dashboard → **Logs** — you'll see every email with delivery status.
