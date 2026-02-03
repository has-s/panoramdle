import os
from databases import Database
from sqlalchemy import MetaData
from dotenv import load_dotenv

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
metadata = MetaData()

__all__ = ["database", "metadata"]