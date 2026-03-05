import sqlalchemy
from sqlalchemy import text

metadata = sqlalchemy.MetaData()

moderators = sqlalchemy.Table(
    "moderators",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("username", sqlalchemy.String(50), unique=True, nullable=False),
    sqlalchemy.Column("password_hash", sqlalchemy.Text, nullable=False),
    sqlalchemy.Column("email", sqlalchemy.String(100), nullable=True),
    sqlalchemy.Column("role", sqlalchemy.String(20), nullable=False, server_default="moderator"),
    sqlalchemy.Column("is_active", sqlalchemy.Boolean, nullable=False, server_default="true"),
    sqlalchemy.Column("status", sqlalchemy.String(20), nullable=False, server_default="active"),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=text("CURRENT_TIMESTAMP")),
    sqlalchemy.Column("last_login", sqlalchemy.DateTime, nullable=True),
    sqlalchemy.Column("created_by", sqlalchemy.Integer, nullable=True),
)

sessions = sqlalchemy.Table(
    "sessions",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True),
    sqlalchemy.Column("moderator_id", sqlalchemy.Integer, nullable=False),
    sqlalchemy.Column("expires_at", sqlalchemy.DateTime, nullable=False),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=text("CURRENT_TIMESTAMP")),
    sqlalchemy.Column("last_activity", sqlalchemy.DateTime, server_default=text("CURRENT_TIMESTAMP")),
    sqlalchemy.Column("ip_address", sqlalchemy.String(45), nullable=True),
    sqlalchemy.Column("user_agent", sqlalchemy.Text, nullable=True),
)

audit_log = sqlalchemy.Table(
    "audit_log",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.Integer, primary_key=True, autoincrement=True),
    sqlalchemy.Column("moderator_id", sqlalchemy.Integer, nullable=True),
    sqlalchemy.Column("action", sqlalchemy.String(50), nullable=False),
    sqlalchemy.Column("target_type", sqlalchemy.String(50), nullable=True),
    sqlalchemy.Column("target_id", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("details", sqlalchemy.JSON, nullable=True),
    sqlalchemy.Column("ip_address", sqlalchemy.String(45), nullable=True),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=text("CURRENT_TIMESTAMP")),
)

__all__ = ["moderators", "sessions", "audit_log"]