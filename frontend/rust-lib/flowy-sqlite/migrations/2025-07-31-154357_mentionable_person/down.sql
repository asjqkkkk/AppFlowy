-- This file should undo anything in `up.sql`
DROP INDEX IF EXISTS idx_mentionable_person_workspace_id;
DROP INDEX IF EXISTS idx_mentionable_person_last_mentioned;
DROP INDEX IF EXISTS idx_mentionable_person_role;
DROP INDEX IF EXISTS idx_mentionable_person_email;
DROP TABLE mentionable_person;