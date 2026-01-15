import os
import sqlalchemy
from databases import Database
from dotenv import load_dotenv
from sqlalchemy import text

SCRIPT_DIR = os.path.dirname(__file__)
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))

APP_ENV = os.getenv("APP_ENV", "local")
dotenv_file = os.path.join(PROJECT_ROOT, ".env.docker" if APP_ENV == "docker" else ".env.local")
load_dotenv(dotenv_file)

user = os.getenv("POSTGRES_USER", "user")
password = os.getenv("POSTGRES_PASSWORD", "pass")
db_name = os.getenv("POSTGRES_DB", "newsdb")
host = os.getenv("POSTGRES_HOST") or ("db" if APP_ENV == "docker" else "localhost")

DATABASE_URL = f"postgresql://{user}:{password}@{host}:5432/{db_name}"
database = Database(DATABASE_URL)
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
    sqlalchemy.Column("created_at", sqlalchemy.DateTime, server_default=text("CURRENT_TIMESTAMP"))
)