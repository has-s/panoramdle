-- migrations/001_initial.sql

CREATE TABLE IF NOT EXISTS news (
    id VARCHAR(36) PRIMARY KEY,
    headline TEXT NOT NULL,
    text TEXT,
    format VARCHAR(10) NOT NULL,
    is_real BOOLEAN NOT NULL,
    media_url TEXT,
    source_name VARCHAR(255),
    published_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_news_published_date ON news(published_date);
CREATE INDEX IF NOT EXISTS idx_news_is_real ON news(is_real);