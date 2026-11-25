import { createClient } from '@supabase/supabase-js';

// Anon key only. Row Level Security protects data; never use the service-role key here.
export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY,
);
