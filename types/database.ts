// ============================================================
// types/database.ts — Supabase database type definitions
// These mirror the PostgreSQL schema exactly.
// ============================================================

export type UserRole = 'student' | 'driver' | 'admin'
export type TripStatus = 'scheduled' | 'active' | 'completed' | 'cancelled'
export type BoardingStatus = 'pending' | 'confirmed' | 'rejected'
export type NotificationEvent =
  | 'BUS_APPROACHING'
  | 'BUS_DELAYED'
  | 'BOARDING_CONFIRMED'
  | 'TRIP_STARTED'
  | 'TRIP_ENDED'
  | 'ETA_CHANGED'

export interface Profile {
  id: string // auth.users.id
  email: string
  full_name: string | null
  role: UserRole
  avatar_url: string | null
  college_id: string | null
  created_at: string
  updated_at: string
}

export interface College {
  id: string
  name: string
  address: string | null
  latitude: number | null
  longitude: number | null
  created_at: string
}

export interface Student {
  id: string
  profile_id: string
  college_id: string | null
  student_id_number: string | null
  phone: string | null
  created_at: string
  updated_at: string
  // joined
  profile?: Profile
  college?: College
}

export interface Driver {
  id: string
  profile_id: string
  license_number: string | null
  phone: string | null
  is_active: boolean
  created_at: string
  updated_at: string
  // joined
  profile?: Profile
}

export interface Bus {
  id: string
  bus_number: string
  plate_number: string | null
  capacity: number
  route_id: string | null
  assigned_driver_id: string | null
  is_active: boolean
  created_at: string
  updated_at: string
  // joined
  route?: Route
  driver?: Driver
}

export interface Route {
  id: string
  name: string
  description: string | null
  college_id: string | null
  is_active: boolean
  created_at: string
  updated_at: string
  // joined
  stops?: RouteStop[]
  college?: College
}

export interface Stop {
  id: string
  name: string
  latitude: number
  longitude: number
  address: string | null
  created_at: string
}

export interface RouteStop {
  id: string
  route_id: string
  stop_id: string
  stop_order: number
  estimated_minutes_from_start: number | null
  created_at: string
  // joined
  stop?: Stop
  route?: Route
}

export interface Trip {
  id: string
  bus_id: string
  route_id: string
  driver_id: string | null
  status: TripStatus
  started_at: string | null
  ended_at: string | null
  scheduled_at: string | null
  recorded_onboard_count: number
  created_at: string
  updated_at: string
  // joined
  bus?: Bus
  route?: Route
  driver?: Driver
}

export interface BusLocation {
  id: string
  trip_id: string
  bus_id: string
  latitude: number
  longitude: number
  accuracy: number | null
  speed: number | null
  heading: number | null
  recorded_at: string
}

export interface BoardingRecord {
  id: string
  student_id: string
  bus_id: string
  trip_id: string
  qr_token_id: string | null
  boarded_at: string
  student_latitude: number | null
  student_longitude: number | null
  validation_status: BoardingStatus
  validation_note: string | null
  // joined
  student?: Student
  trip?: Trip
}

export interface QrToken {
  id: string
  bus_id: string
  trip_id: string | null
  token: string
  expires_at: string
  is_used: boolean
  created_at: string
  // joined
  bus?: Bus
  trip?: Trip
}

export interface StudentFavouriteStop {
  id: string
  student_id: string
  stop_id: string
  reminder_minutes: number // 2, 5, or 10
  created_at: string
  // joined
  stop?: Stop
}

export interface Notification {
  id: string
  student_id: string
  event: NotificationEvent
  title: string
  body: string
  trip_id: string | null
  stop_id: string | null
  is_read: boolean
  created_at: string
}

// ─── Runtime computed types ───────────────────────────────────────────────────

export interface BusWithEta extends Bus {
  currentLocation?: BusLocation
  eta?: ETAResult
  activeTrip?: Trip
}

export interface ETAResult {
  stopId: string
  stopName: string
  etaMinutes: number | null
  distanceMeters: number | null
  isAvailable: boolean
  source: 'google_directions' | 'speed_estimate' | 'unavailable'
  calculatedAt: string
}

export interface DelayAnalysis {
  tripId: string
  busId: string
  isDelayed: boolean
  delayMinutes: number | null
  status: 'on_time' | 'early' | 'delayed' | 'unknown'
  message: string
  confidence: 'high' | 'medium' | 'low'
  calculatedAt: string
}
