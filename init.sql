-- init.sql

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS news (
    id TEXT PRIMARY KEY,
    headline TEXT NOT NULL,
    text TEXT,
    format VARCHAR(10) NOT NULL,
    is_real BOOLEAN NOT NULL,
    media_url TEXT,
    source_name TEXT,
    published_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_news_headline ON news(headline);

CREATE INDEX IF NOT EXISTS idx_news_is_real ON news(is_real);
CREATE INDEX IF NOT EXISTS idx_news_created_at ON news(created_at);
CREATE INDEX IF NOT EXISTS idx_news_published_date ON news(published_date);