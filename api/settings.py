from pydantic import BaseModel
from dotenv import load_dotenv
from pathlib import Path
import os

load_dotenv(dotenv_path=Path(__file__).resolve().parents[1] / ".env")

class Settings(BaseModel):
    database_url: str = os.getenv("DATABASE_URL", "")
    db_schema: str = os.getenv("DB_SCHEMA", "public")
    admin_user: str = os.getenv("ADMIN_USER", "admin")
    admin_pass: str = os.getenv("ADMIN_PASS", "admin123")

settings = Settings()

if not settings.database_url:
    raise RuntimeError("DATABASE_URL is missing")

import os

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = os.getenv("SMTP_PORT")
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASS = os.getenv("SMTP_PASS")
MAIL_FROM = os.getenv("MAIL_FROM")

