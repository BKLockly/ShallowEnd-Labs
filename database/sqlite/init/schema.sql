-- shlabs_notes.db —— SQLite 库栈初始化（仿 notes 应用库，含真实感敏感数据，
-- 供数据库驱动插件功能测试与 mem_search 等内存凭据插件靶标使用）
PRAGMA journal_mode = DELETE;

CREATE TABLE users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    username      TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    email         TEXT NOT NULL,
    role          TEXT NOT NULL DEFAULT 'user',
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE sessions (
    token       TEXT PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id),
    expires_at  TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE posts (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id    INTEGER NOT NULL REFERENCES users(id),
    title      TEXT NOT NULL,
    body       TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE app_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT INTO users (username, password_hash, email, role) VALUES
    ('admin',   '$2b$12$KIXQ3m7Qy9Oe9T7f2bV6H.8vJ7Kq0eR1sL2mN3pQ4rS5tU6vW7xY', 'admin@shlabs.local', 'admin'),
    ('dev',     '$2b$12$8Yy9Zq1Wx2Ev3Rb4Nc5Md.6fG7hJ8kL9mN0pQ1rS2tU3vW4xY5zA', 'dev@shlabs.local',   'user'),
    ('service', '$2b$12$3zA4bC5dE6fG7hI8jK9l.0mN1oP2qR3sT4uV5wX6yZ7aB8cD9eF', 'svc@shlabs.local',   'service');

INSERT INTO sessions (token, user_id, expires_at) VALUES
    ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOjEsInJvbGUiOiJhZG1pbiJ9.9b1f2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1', 1, '2026-12-31 23:59:59'),
    ('shlabs_session_7f3a9c1e2b4d6f8a0c2e4b6d8f0a2c4e6b8d0f2a4c6e8b0d2f4a6c8e0b2d4f6a', 2, '2026-11-30 23:59:59');

INSERT INTO posts (user_id, title, body) VALUES
    (1, 'Welcome to Shlabs Notes', 'Internal note-taking service. Do not store production credentials here.'),
    (2, 'Rotation schedule', 'API keys rotate on the first Monday of each month.');

INSERT INTO app_config (key, value) VALUES
    ('smtp_host',        'smtp.shlabs.local'),
    ('smtp_user',        'notes-mailer'),
    ('smtp_password',    'shlabs-smtp-p4ssw0rd'),
    ('aws_access_key',   'AKIAIOSFODNN7EXAMPLE'),
    ('aws_secret_key',   'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'),
    ('stripe_key',       'sk_test_shlabs0X4mp1e9kEys00T0k3n'),
    ('internal_api_url', 'http://notes-api.internal.shlabs.local:21531/v1');
