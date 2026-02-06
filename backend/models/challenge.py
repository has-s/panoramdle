from sqlalchemy import Table, Column, Integer, Date, Boolean, TIMESTAMP, ForeignKey, Index
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func

from backend.db import metadata

daily_challenge = Table(
    "daily_challenge",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("challenge_date", Date, nullable=False, unique=True),
    Column("news_snapshot", JSONB, nullable=False),
    Column("total_attempts", Integer, server_default="0"),
    Column("total_correct", Integer, server_default="0"),
    Column("created_at", TIMESTAMP, server_default=func.now()),
    Column("created_by", Integer, ForeignKey("moderators.id")),
    Column("is_custom", Boolean, default=False),

    Index("idx_daily_challenge_date", "challenge_date"),
    Index("idx_daily_challenge_created_at", "created_at"),
)