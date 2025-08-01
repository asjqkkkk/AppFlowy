-- Your SQL goes here
CREATE TABLE IF NOT EXISTS mentionable_person (
  person_id TEXT NOT NULL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role INTEGER NOT NULL,
  avatar_url TEXT,
  cover_image_url TEXT,
  custom_image_url TEXT,
  description TEXT,
  invited BOOLEAN NOT NULL DEFAULT FALSE,
  last_mentioned_at DATETIME
);

-- Create index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_mentionable_person_email ON mentionable_person(email);

-- Create index on role for filtering by person type
CREATE INDEX IF NOT EXISTS idx_mentionable_person_role ON mentionable_person(role);

-- Create index on last_mentioned_at for sorting by recent mentions
CREATE INDEX IF NOT EXISTS idx_mentionable_person_last_mentioned ON mentionable_person(last_mentioned_at);
