-- Update mentionable_person table to use composite primary key (person_id, workspace_id)

-- First, drop the existing primary key constraint
PRAGMA foreign_keys=off;

-- Create a temporary table with the new schema
CREATE TABLE mentionable_person_new (
  person_id TEXT NOT NULL,
  workspace_id TEXT NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role INTEGER NOT NULL,
  avatar_url TEXT,
  cover_image_url TEXT,
  custom_image_url TEXT,
  description TEXT,
  invited BOOLEAN NOT NULL DEFAULT FALSE,
  last_mentioned_at DATETIME,
  PRIMARY KEY (person_id, workspace_id)
);

-- Copy data from the old table to the new table
INSERT INTO mentionable_person_new 
SELECT person_id, workspace_id, name, email, role, avatar_url, cover_image_url, custom_image_url, description, invited, last_mentioned_at
FROM mentionable_person;

-- Drop the old table
DROP TABLE mentionable_person;

-- Rename the new table to the original name
ALTER TABLE mentionable_person_new RENAME TO mentionable_person;

-- Recreate the indexes
CREATE INDEX IF NOT EXISTS idx_mentionable_person_email ON mentionable_person(email);
CREATE INDEX IF NOT EXISTS idx_mentionable_person_role ON mentionable_person(role);
CREATE INDEX IF NOT EXISTS idx_mentionable_person_last_mentioned ON mentionable_person(last_mentioned_at);

PRAGMA foreign_keys=on;
