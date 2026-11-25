# E-Commerce Platform

React (Vite, Tailwind) + Express + Supabase + Paystack (NGN). Deploys to Railway.

## Local setup
1. Create a Supabase project. In the SQL editor run `database/schema.sql`, then `policies.sql`, then `seed.sql`.
2. `cd server && cp .env.example .env` and fill in the values. `npm install && npm run dev` (API on :5000).
3. `cd client && cp .env.example .env` and fill in the values. `npm install && npm run dev` (app on :5173).
4. Check http://localhost:5000/api/health returns `database: up`.

## Security rules
- `SUPABASE_SERVICE_ROLE_KEY` and `PAYSTACK_SECRET_KEY` live only in `server/.env`.
- The client uses only the Supabase anon key; RLS protects data.
