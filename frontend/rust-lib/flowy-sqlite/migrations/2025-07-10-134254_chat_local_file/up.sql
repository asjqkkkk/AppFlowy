-- Your SQL goes here
CREATE TABLE chat_local_file
(
    file_id      TEXT PRIMARY KEY,
    chat_id      TEXT NOT NULL,
    file_path    TEXT NOT NULL,
    file_content TEXT NOT NULL
);