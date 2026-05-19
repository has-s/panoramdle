from sqlalchemy import Table, Column, Integer, Date, String, TIMESTAMP, UniqueConstraint, Index
from sqlalchemy.sql import func

from backend.db import metadata

daily_submissions = Table(
    "daily_submissions",
    metadata,
    Column("id", Integer, primary_key=True),
    Column("challenge_date", Date, nullable=False),
    Column("ip_address", String(45), nullable=False),
    Column("correct_count", Integer, nullable=False),
    Column("submitted_at", TIMESTAMP, server_default=func.now()),

    UniqueConstraint("challenge_date", "ip_address", name="daily_submissions_ip_date_unique"),
    Index("idx_daily_submissions_date", "challenge_date"),
    Index("idx_daily_submissions_ip", "ip_address"),
)