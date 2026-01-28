import psycopg
from psycopg.rows import dict_row
from .settings import settings

def get_conn():
    return psycopg.connect(settings.database_url, row_factory=dict_row)

def init_db():
    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {schema}.articles (
                    id SERIAL PRIMARY KEY,
                    name TEXT NOT NULL UNIQUE,
                    stock INT NOT NULL
                )
            """)
            cur.execute(f"""
                CREATE TABLE IF NOT EXISTS {schema}.orders (
                    id SERIAL PRIMARY KEY,
                    article_id INT NOT NULL,
                    buyer_email TEXT NOT NULL,
                    price_cents INT NOT NULL DEFAULT 0,
                    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
            """)
        conn.commit()
