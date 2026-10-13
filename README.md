# SMA Football Prediction League

A multi-user football prediction competition website for the Sports Mathematics & Analytics Club. This is a real database-backed web application, not a mock prototype, once Supabase has been configured. It is independent of any academic IA.

## Stack
- Next.js 15 + React + TypeScript, deployable on Vercel
- Supabase Auth (password sign-in, email verification, password reset emails)
- Supabase PostgreSQL + Row Level Security policies + transaction-time guards
- All timestamps stored in UTC; match displays use Jakarta (WIB)

## Initial setup (about 10 minutes with access to accounts)
1. Create a Supabase project at https://supabase.com/dashboard . Its hosted PostgreSQL database is necessary for multi-computer persistence; SQLite on Vercel is not a safe shared datastore.
2. Paste `supabase/schema.sql` into Supabase's SQL Editor and run it ONCE. If you change schema later, review SQL migration changes instead of blindly replaying create policies.
3. Copy the **Project URL** and **publishable/anon public key** from Supabase's API settings. Do not use or expose a `service_role` secret in NEXT_PUBLIC variables.
4. Copy `.env.example` to `.env.local` and fill the two variables.
5. `npm install`, then `npm run dev` (http://localhost:3000).
6. In Supabase Auth → URL Configuration set Site URL to your deployed domain (or http://localhost:3000 locally) and the appropriate redirect URLs. Turn on email confirmation for a real deployment, and configure an SMTP provider as needed for email delivery.
7. Sign up once with your personal email. In SQL Editor, promote only that account with `update public.profiles set role='admin' where id=(select id from auth.users where email='YOUR_EMAIL');` . Sign out and in again, or refresh. Never put the admin promotion SQL in browser code.
8. In Vercel, import this project via your GitHub repository and define `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` for Production and Preview. Deploy. Set the deployed URL in Supabase Auth redirects. Run a 2-account smoke test using separate browsers.

## Features
- Separate Admin and Member navigation and database-enforced permissions
- Member registration, login, profile updates, password reset request
- Admin: manually create/edit/delete fixtures with restrictions, CSV bulk import, enter full-time goals after kickoff, activate/deactivate members, export submissions to CSV
- Member: submit/edit 3-way probabilities until deadline, history, status and score
- Club-wide lower-is-better average three-way Brier Score leaderboard, exclude unscored matches and inactive users
- Brier Score and outcome calibration summaries; database data shared by all devices

## CSV import
Plain CSV header: `league,home_team,away_team,kickoff_at,deadline_at` . Timestamp values should be ISO 8601 with offset, e.g. `2026-10-17T19:00:00+07:00` . Basic CSV import does **not** handle quoted commas in team names. For large / complex imports use a proper CSV parser.

## Caveats to address before a large public launch
- The public app currently makes all predictions visible to active authenticated members because leaderboard / statistical reporting is computed client-side. **Members can inspect other members' forecasts, even before kick-off.** For independent prediction competitions, replace the member read policy with a self-only policy and calculate leaderboard/calibration using secure Postgres RPCs that expose aggregates after deadlines. You may prefer to delay official use until this is changed.
- The application does not currently supply invitation-only enrollment, anti-spam throttling above Supabase Auth defaults, detailed audit logs, or historical score snapshots. Consider adding them for a schoolwide competition.
- Password reset requests are sent by Supabase. Completion of a recovery session requires setting a new password using `supabase.auth.updateUser`; this starter currently only sends the email; use Supabase hosted recovery flow or implement a dedicated recovery page before relying on self-service recovery.
- Login and roles are real only after Supabase is configured and deployed. No demo users or passwords are included.

## Security
Supabase Row Level Security checks every table read/write; database triggers validate actual server time for prediction deadlines, prevent ordinary members editing match results, protect match edits when there are predictions and check probability totals. Never use the Supabase service role key in the client.
