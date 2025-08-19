-- Create a temporary table with the new schema
CREATE TABLE chat_local_file_new (
    file_id      TEXT NOT NULL PRIMARY KEY,
    chat_id      TEXT NOT NULL,
    file_path    TEXT NOT NULL,
    file_content TEXT NOT NULL
);

-- Copy data from the old table to the new table
INSERT INTO chat_local_file_new
SELECT file_id, chat_id, file_path, file_content
FROM chat_local_file
WHERE file_id IS NOT NULL;

-- Drop the old table
DROP TABLE chat_local_file;

-- Rename the new table to the original name
ALTER TABLE chat_local_file_new RENAME TO chat_local_file;
