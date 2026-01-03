import sqlalchemy
from databases import Database
import os
from dotenv import load_dotenv

env = os.getenv("APP_ENV", "local")

if env == "docker":
    load_dotenv(".env.docker")
else:
    load_dotenv(".env.local")

user = os.environ["POSTGRES_USER"]
password = os.environ["POSTGRES_PASSWORD"]
db_name = os.environ["POSTGRES_DB"]
host = os.environ["POSTGRES_HOST"]

DATABASE_URL = f"postgresql://{user}:{password}@{host}:5432/{db_name}"
database = Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()

import uuid
news = sqlalchemy.Table(
    "news",
    metadata,
    sqlalchemy.Column("id", sqlalchemy.String, primary_key=True, default=lambda: str(uuid.uuid4())),
    sqlalchemy.Column("headline", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("text", sqlalchemy.Text, nullable=True),
    sqlalchemy.Column("format", sqlalchemy.String, nullable=False),
    sqlalchemy.Column("is_real", sqlalchemy.Boolean, nullable=False),
    sqlalchemy.Column("media_url", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("source_name", sqlalchemy.String, nullable=True),
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=sqlalchemy.text("CURRENT_TIMESTAMP")),
)