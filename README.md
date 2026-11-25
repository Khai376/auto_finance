# Car Payment System + Supabase Auth

1. Create a Supabase project.
2. SQL Editor: run `supabase.sql`.
3. Authentication > Users: create the email/password user (or enable public signup if desired).
4. Copy `.env.example` to `.env` and fill `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY`.
5. `npm install && npm run dev`
6. Before GitHub Pages deployment, set the repository base in vite.config.js, then `GITHUB_PAGES=true npm run build && npm run deploy`.

Security: Storage buckets are private and access is scoped by auth.uid(). Do not put service_role keys in the frontend.
