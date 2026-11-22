CREATE TABLE split_days (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  name_key TEXT NOT NULL UNIQUE CHECK (length(name_key) > 0)
);
CREATE TABLE locations (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  name_key TEXT NOT NULL UNIQUE CHECK (length(name_key) > 0)
);
CREATE TABLE exercises (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL CHECK (length(trim(name)) > 0),
  name_key TEXT NOT NULL CHECK (length(name_key) > 0),
  location_id INTEGER REFERENCES locations(id) ON DELETE RESTRICT,
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1))
);
CREATE UNIQUE INDEX idx_exercise_any_name ON exercises(name_key) WHERE location_id IS NULL;
CREATE UNIQUE INDEX idx_exercise_location_name ON exercises(name_key, location_id) WHERE location_id IS NOT NULL;
CREATE INDEX idx_exercise_location ON exercises(location_id);
CREATE TABLE exercise_split_days (
  exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  split_day_id INTEGER NOT NULL REFERENCES split_days(id) ON DELETE CASCADE,
  PRIMARY KEY (exercise_id, split_day_id)
);
CREATE INDEX idx_split_exercises ON exercise_split_days(split_day_id, exercise_id);
CREATE TABLE exercise_entries (
  id INTEGER PRIMARY KEY,
  exercise_id INTEGER NOT NULL REFERENCES exercises(id) ON DELETE RESTRICT,
  performed_at_ms INTEGER NOT NULL,
  performed_utc_offset_minutes INTEGER NOT NULL
    CHECK (performed_utc_offset_minutes BETWEEN -840 AND 840),
  note TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
CREATE INDEX idx_exercise_history
  ON exercise_entries(exercise_id, performed_at_ms DESC, id DESC);
CREATE TABLE entry_sets (
  id INTEGER PRIMARY KEY,
  entry_id INTEGER NOT NULL REFERENCES exercise_entries(id) ON DELETE CASCADE,
  position INTEGER NOT NULL CHECK (position >= 1),
  weight_grams INTEGER NOT NULL CHECK (weight_grams >= 0),
  reps_tenths INTEGER NOT NULL CHECK (reps_tenths > 0),
  UNIQUE (entry_id, position)
);
CREATE TABLE entry_drafts (
  exercise_id INTEGER PRIMARY KEY REFERENCES exercises(id) ON DELETE CASCADE,
  editing_entry_id INTEGER UNIQUE REFERENCES exercise_entries(id) ON DELETE CASCADE,
  payload_json TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
CREATE TABLE body_weights (
  id INTEGER PRIMARY KEY,
  day TEXT NOT NULL UNIQUE,
  weight_grams INTEGER NOT NULL CHECK (weight_grams > 0),
  note TEXT,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL
);
