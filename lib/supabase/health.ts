// ============================================================
// lib/supabase/health.ts — Connection health check utilities
// ============================================================

import { getSupabaseClient } from './client'

export interface SupabaseHealthResult {
  connected: boolean
  latencyMs: number | null
  error: string | null
  missingEnvVars: string[]
}

export async function checkSupabaseHealth(): Promise<SupabaseHealthResult> {
  const missingEnvVars: string[] = []

  if (!process.env.NEXT_PUBLIC_SUPABASE_URL ||
      process.env.NEXT_PUBLIC_SUPABASE_URL === 'https://your-project-id.supabase.co') {
    missingEnvVars.push('NEXT_PUBLIC_SUPABASE_URL')
  }

  if (!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
      process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY === 'your-supabase-anon-key') {
    missingEnvVars.push('NEXT_PUBLIC_SUPABASE_ANON_KEY')
  }

  if (missingEnvVars.length > 0) {
    return {
      connected: false,
      latencyMs: null,
      error: `Missing environment variables: ${missingEnvVars.join(', ')}`,
      missingEnvVars,
    }
  }

  try {
    const start = Date.now()
    const supabase = getSupabaseClient()
    // Light query — just ping the colleges table
    const { error } = await supabase.from('colleges').select('id').limit(1)
    const latencyMs = Date.now() - start

    if (error) {
      return {
        connected: false,
        latencyMs,
        error: error.message,
        missingEnvVars: [],
      }
    }

    return { connected: true, latencyMs, error: null, missingEnvVars: [] }
  } catch (err) {
    return {
      connected: false,
      latencyMs: null,
      error: err instanceof Error ? err.message : 'Unknown error',
      missingEnvVars: [],
    }
  }
}

export function getMapsApiKeyStatus(): { configured: boolean; reason?: string } {
  const key = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY
  if (!key || key === 'your-google-maps-api-key') {
    return {
      configured: false,
      reason: 'NEXT_PUBLIC_GOOGLE_MAPS_API_KEY is not set in .env.local',
    }
  }
  return { configured: true }
}
