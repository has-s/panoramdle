CREATE TABLE IF NOT EXISTS news (
    id UUID PRIMARY KEY,
    headline TEXT NOT NULL,
    text TEXT,
    format VARCHAR(10) NOT NULL,
    is_real BOOLEAN NOT NULL,
    media_url TEXT,
    source_name TEXT
);