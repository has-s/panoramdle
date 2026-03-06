import sqlalchemy
from sqlalchemy import text

metadata = sqlalchemy.MetaData()

news = sqlalchemy.Table(
    "news",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("headline", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("text", sqlalchemy.Text, nullable=True),
    sqlalchemy.Column("format", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("is_real", sqlalchemy.Boolean, nullable=False),
    sqlalchemy.Column("media_url", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("source_name", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("published_date", sqlalchemy.Date, nullable=True),
    sqlalchemy.Column("author_comment", sqlalchemy.Text, nullable=True),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=text("CURRENT_TIMESTAMP")),
    sqlalchemy.Column("created_by", sqlalchemy.Integer, nullable=True),
    sqlalchemy.Column("edit_history", sqlalchemy.JSON, server_default=text("'[]'::json")),
)