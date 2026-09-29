// ============================================================
// lib/supabase/client.ts — Browser-side Supabase client
// Uses @supabase/ssr for proper cookie-based auth in Next.js.
// ============================================================
import { createBrowserClient } from '@supabase/ssr'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

if (!supabaseUrl || supabaseUrl === 'https://your-project-id.supabase.co') {
  if (typeof window !== 'undefined') {
    console.error(
      '[SmartBus] NEXT_PUBLIC_SUPABASE_URL is not configured. ' +
        'Copy .env.example to .env.local and fill in your Supabase project URL.'
    )
  }
}

if (!supabaseAnonKey || supabaseAnonKey === 'your-supabase-anon-key') {
  if (typeof window !== 'undefined') {
    console.error(
      '[SmartBus] NEXT_PUBLIC_SUPABASE_ANON_KEY is not configured. ' +
        'Copy .env.example to .env.local and fill in your Supabase anon key.'
    )
  }
}

export function createClient() {
  return createBrowserClient(
    supabaseUrl ?? '',
    supabaseAnonKey ?? ''
  )
}

// Singleton for convenience in client components
let _client: ReturnType<typeof createClient> | null = null

export function getSupabaseClient() {
  if (!_client) {
    _client = createClient()
  }
  return _client
}
