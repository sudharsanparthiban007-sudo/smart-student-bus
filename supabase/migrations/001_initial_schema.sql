-- ============================================================
-- Smart Student Bus — Complete PostgreSQL Schema + RLS
-- Run this in your Supabase SQL Editor.
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── ENUMS ────────────────────────────────────────────────────────────────────

CREATE TYPE user_role AS ENUM ('student', 'driver', 'admin');
CREATE TYPE trip_status AS ENUM ('scheduled', 'active', 'completed', 'cancelled');
CREATE TYPE boarding_status AS ENUM ('pending', 'confirmed', 'rejected');
CREATE TYPE notification_event AS ENUM (
  'BUS_APPROACHING',
  'BUS_DELAYED',
  'BOARDING_CONFIRMED',
  'TRIP_STARTED',
  'TRIP_ENDED',
  'ETA_CHANGED'
);

-- ─── COLLEGES ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS colleges (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  address     TEXT,
  latitude    DOUBLE PRECISION,
  longitude   DOUBLE PRECISION,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── PROFILES ────────────────────────────────────────────────────────────────
-- Extends auth.users. Created automatically via trigger on signup.

CREATE TABLE IF NOT EXISTS profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email       TEXT NOT NULL,
  full_name   TEXT,
  role        user_role NOT NULL DEFAULT 'student',
  avatar_url  TEXT,
  college_id  UUID REFERENCES colleges(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── STUDENTS ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS students (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id        UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  college_id        UUID REFERENCES colleges(id) ON DELETE SET NULL,
  student_id_number TEXT,
  phone             TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── DRIVERS ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS drivers (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id     UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  license_number TEXT,
  phone          TEXT,
  is_active      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── ROUTES ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS routes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name        TEXT NOT NULL,
  description TEXT,
  college_id  UUID REFERENCES colleges(id) ON DELETE SET NULL,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── STOPS ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS stops (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name       TEXT NOT NULL,
  latitude   DOUBLE PRECISION NOT NULL,
  longitude  DOUBLE PRECISION NOT NULL,
  address    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── ROUTE_STOPS (ordered) ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS route_stops (
  id                              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_id                        UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  stop_id                         UUID NOT NULL REFERENCES stops(id) ON DELETE CASCADE,
  stop_order                      INTEGER NOT NULL,
  estimated_minutes_from_start    INTEGER,
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (route_id, stop_order),
  UNIQUE (route_id, stop_id)
);

-- ─── BUSES ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS buses (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bus_number         TEXT NOT NULL UNIQUE,
  plate_number       TEXT,
  capacity           INTEGER NOT NULL DEFAULT 50,
  route_id           UUID REFERENCES routes(id) ON DELETE SET NULL,
  assigned_driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
  is_active          BOOLEAN NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── TRIPS ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS trips (
  id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bus_id                  UUID NOT NULL REFERENCES buses(id) ON DELETE CASCADE,
  route_id                UUID NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
  driver_id               UUID REFERENCES drivers(id) ON DELETE SET NULL,
  status                  trip_status NOT NULL DEFAULT 'scheduled',
  started_at              TIMESTAMPTZ,
  ended_at                TIMESTAMPTZ,
  scheduled_at            TIMESTAMPTZ,
  recorded_onboard_count  INTEGER NOT NULL DEFAULT 0,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─── BUS_LOCATIONS ────────────────────────────────────────────────────────────
-- High-frequency location data. Keep partitioned/pruned in production.

CREATE TABLE IF NOT EXISTS bus_locations (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  trip_id     UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  bus_id      UUID NOT NULL REFERENCES buses(id) ON DELETE CASCADE,
  latitude    DOUBLE PRECISION NOT NULL,
  longitude   DOUBLE PRECISION NOT NULL,
  accuracy    DOUBLE PRECISION,
  speed       DOUBLE PRECISION,
  heading     DOUBLE PRECISION,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS bus_locations_trip_id_idx ON bus_locations(trip_id);
CREATE INDEX IF NOT EXISTS bus_locations_recorded_at_idx ON bus_locations(recorded_at DESC);

-- ─── QR_TOKENS ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS qr_tokens (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  bus_id     UUID NOT NULL REFERENCES buses(id) ON DELETE CASCADE,
  trip_id    UUID REFERENCES trips(id) ON DELETE SET NULL,
  token      TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(32), 'hex'),
  expires_at TIMESTAMPTZ NOT NULL,
  is_used    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS qr_tokens_token_idx ON qr_tokens(token);

-- ─── BOARDING_RECORDS ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS boarding_records (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id        UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  bus_id            UUID NOT NULL REFERENCES buses(id) ON DELETE CASCADE,
  trip_id           UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  qr_token_id       UUID REFERENCES qr_tokens(id) ON DELETE SET NULL,
  boarded_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  student_latitude  DOUBLE PRECISION,
  student_longitude DOUBLE PRECISION,
  validation_status boarding_status NOT NULL DEFAULT 'pending',
  validation_note   TEXT,
  UNIQUE (student_id, trip_id) -- prevent duplicate boarding
);

-- ─── STUDENT_FAVOURITE_STOPS ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS student_favourite_stops (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id       UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  stop_id          UUID NOT NULL REFERENCES stops(id) ON DELETE CASCADE,
  reminder_minutes INTEGER NOT NULL DEFAULT 5 CHECK (reminder_minutes IN (2, 5, 10)),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (student_id, stop_id)
);

-- ─── NOTIFICATIONS ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS notifications (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  event      notification_event NOT NULL,
  title      TEXT NOT NULL,
  body       TEXT NOT NULL,
  trip_id    UUID REFERENCES trips(id) ON DELETE SET NULL,
  stop_id    UUID REFERENCES stops(id) ON DELETE SET NULL,
  is_read    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS notifications_student_id_idx ON notifications(student_id);
CREATE INDEX IF NOT EXISTS notifications_created_at_idx ON notifications(created_at DESC);

-- ─── TRIGGER: auto-create profile on signup ───────────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE((NEW.raw_user_meta_data->>'role')::user_role, 'student')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ─── TRIGGER: auto-create student record on profile creation ─────────────────

CREATE OR REPLACE FUNCTION handle_new_student_profile()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'student' THEN
    INSERT INTO students (profile_id, college_id)
    VALUES (NEW.id, NEW.college_id)
    ON CONFLICT (profile_id) DO NOTHING;
  ELSIF NEW.role = 'driver' THEN
    INSERT INTO drivers (profile_id)
    VALUES (NEW.id)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_profile_created ON profiles;
CREATE TRIGGER on_profile_created
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION handle_new_student_profile();

-- ─── TRIGGER: increment onboard count on confirmed boarding ───────────────────

CREATE OR REPLACE FUNCTION handle_boarding_confirmed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.validation_status = 'confirmed' AND
     (OLD IS NULL OR OLD.validation_status <> 'confirmed') THEN
    UPDATE trips
    SET recorded_onboard_count = recorded_onboard_count + 1,
        updated_at = NOW()
    WHERE id = NEW.trip_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_boarding_confirmed ON boarding_records;
CREATE TRIGGER on_boarding_confirmed
  AFTER INSERT OR UPDATE ON boarding_records
  FOR EACH ROW EXECUTE FUNCTION handle_boarding_confirmed();

-- ─── UPDATED_AT triggers ──────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at    BEFORE UPDATE ON profiles    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_students_updated_at    BEFORE UPDATE ON students    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_drivers_updated_at     BEFORE UPDATE ON drivers     FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_buses_updated_at       BEFORE UPDATE ON buses       FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_routes_updated_at      BEFORE UPDATE ON routes      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER set_trips_updated_at       BEFORE UPDATE ON trips       FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ─── ENABLE REALTIME ──────────────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE bus_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE trips;
ALTER PUBLICATION supabase_realtime ADD TABLE boarding_records;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE profiles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE colleges                ENABLE ROW LEVEL SECURITY;
ALTER TABLE students                ENABLE ROW LEVEL SECURITY;
ALTER TABLE drivers                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE buses                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE routes                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE stops                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE route_stops             ENABLE ROW LEVEL SECURITY;
ALTER TABLE trips                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE bus_locations           ENABLE ROW LEVEL SECURITY;
ALTER TABLE qr_tokens               ENABLE ROW LEVEL SECURITY;
ALTER TABLE boarding_records        ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_favourite_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications           ENABLE ROW LEVEL SECURITY;

-- Helper: get current user role
CREATE OR REPLACE FUNCTION get_user_role()
RETURNS user_role AS $$
  SELECT role FROM profiles WHERE id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Helper: get current student id
CREATE OR REPLACE FUNCTION get_student_id()
RETURNS UUID AS $$
  SELECT id FROM students WHERE profile_id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- Helper: get current driver id
CREATE OR REPLACE FUNCTION get_driver_id()
RETURNS UUID AS $$
  SELECT id FROM drivers WHERE profile_id = auth.uid();
$$ LANGUAGE SQL SECURITY DEFINER STABLE;

-- ── PROFILES ──────────────────────────────────────────────────────────────────
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT USING (id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE USING (id = auth.uid());

CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT USING (get_user_role() = 'admin');

CREATE POLICY "Admins can update all profiles"
  ON profiles FOR UPDATE USING (get_user_role() = 'admin');

-- ── COLLEGES ──────────────────────────────────────────────────────────────────
CREATE POLICY "Anyone authenticated can view colleges"
  ON colleges FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Only admins can manage colleges"
  ON colleges FOR ALL USING (get_user_role() = 'admin');

-- ── STUDENTS ──────────────────────────────────────────────────────────────────
CREATE POLICY "Students can view own record"
  ON students FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "Students can update own record"
  ON students FOR UPDATE USING (profile_id = auth.uid());

CREATE POLICY "Admins can manage all students"
  ON students FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "Drivers can view students (for onboard count context)"
  ON students FOR SELECT USING (get_user_role() = 'driver');

-- ── DRIVERS ───────────────────────────────────────────────────────────────────
CREATE POLICY "Drivers can view own record"
  ON drivers FOR SELECT USING (profile_id = auth.uid());

CREATE POLICY "Drivers can update own record"
  ON drivers FOR UPDATE USING (profile_id = auth.uid());

CREATE POLICY "Admins can manage all drivers"
  ON drivers FOR ALL USING (get_user_role() = 'admin');

-- ── BUSES ─────────────────────────────────────────────────────────────────────
CREATE POLICY "Authenticated users can view active buses"
  ON buses FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = TRUE);

CREATE POLICY "Admins can manage buses"
  ON buses FOR ALL USING (get_user_role() = 'admin');

-- ── ROUTES & STOPS ────────────────────────────────────────────────────────────
CREATE POLICY "Authenticated users can view active routes"
  ON routes FOR SELECT USING (auth.uid() IS NOT NULL AND is_active = TRUE);

CREATE POLICY "Admins can manage routes"
  ON routes FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "Authenticated users can view stops"
  ON stops FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage stops"
  ON stops FOR ALL USING (get_user_role() = 'admin');

CREATE POLICY "Authenticated users can view route_stops"
  ON route_stops FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admins can manage route_stops"
  ON route_stops FOR ALL USING (get_user_role() = 'admin');

-- ── TRIPS ─────────────────────────────────────────────────────────────────────
CREATE POLICY "Authenticated users can view active trips"
  ON trips FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Drivers can update own trips"
  ON trips FOR UPDATE USING (driver_id = get_driver_id());

CREATE POLICY "Admins can manage trips"
  ON trips FOR ALL USING (get_user_role() = 'admin');

-- ── BUS_LOCATIONS ─────────────────────────────────────────────────────────────
CREATE POLICY "Authenticated users can view bus locations"
  ON bus_locations FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Drivers can insert bus locations for own trips"
  ON bus_locations FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM trips t
      JOIN drivers d ON d.id = t.driver_id
      WHERE t.id = bus_locations.trip_id
        AND d.profile_id = auth.uid()
        AND t.status = 'active'
    )
  );

CREATE POLICY "Admins can manage bus locations"
  ON bus_locations FOR ALL USING (get_user_role() = 'admin');

-- ── QR_TOKENS ─────────────────────────────────────────────────────────────────
CREATE POLICY "Authenticated users can view active qr tokens"
  ON qr_tokens FOR SELECT USING (
    auth.uid() IS NOT NULL AND expires_at > NOW()
  );

CREATE POLICY "Admins can manage qr tokens"
  ON qr_tokens FOR ALL USING (get_user_role() = 'admin');

-- ── BOARDING_RECORDS ──────────────────────────────────────────────────────────
CREATE POLICY "Students can view own boarding records"
  ON boarding_records FOR SELECT USING (student_id = get_student_id());

CREATE POLICY "Students can insert own boarding"
  ON boarding_records FOR INSERT WITH CHECK (student_id = get_student_id());

CREATE POLICY "Drivers can view boarding records for own active trip"
  ON boarding_records FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM trips t
      JOIN drivers d ON d.id = t.driver_id
      WHERE t.id = boarding_records.trip_id
        AND d.profile_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage boarding records"
  ON boarding_records FOR ALL USING (get_user_role() = 'admin');

-- ── STUDENT_FAVOURITE_STOPS ───────────────────────────────────────────────────
CREATE POLICY "Students can manage own favourite stops"
  ON student_favourite_stops FOR ALL USING (student_id = get_student_id());

CREATE POLICY "Admins can view all favourite stops"
  ON student_favourite_stops FOR SELECT USING (get_user_role() = 'admin');

-- ── NOTIFICATIONS ─────────────────────────────────────────────────────────────
CREATE POLICY "Students can view own notifications"
  ON notifications FOR SELECT USING (student_id = get_student_id());

CREATE POLICY "Students can update (mark read) own notifications"
  ON notifications FOR UPDATE USING (student_id = get_student_id());

CREATE POLICY "Admins can manage notifications"
  ON notifications FOR ALL USING (get_user_role() = 'admin');

-- ─── SEED: demo college ───────────────────────────────────────────────────────
INSERT INTO colleges (name, address, latitude, longitude)
VALUES ('Demo Engineering College', '123 College Road, Chennai', 13.0827, 80.2707)
ON CONFLICT DO NOTHING;
