from pathlib import Path
from fastapi import FastAPI, HTTPException, Depends, Request, Form
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, EmailStr, Field
from .mail import send_order_mail

import secrets

from .settings import settings
from .db import get_conn, init_db

BASE_DIR = Path(__file__).resolve().parents[1]

app = FastAPI(title="TBGT API", version="1.0.0")
security = HTTPBasic()

templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))
app.mount("/static", StaticFiles(directory=str(BASE_DIR / "static")), name="static")


class ArticleCreate(BaseModel):
    name: str = Field(min_length=1)
    stock: int = Field(ge=0)

class ArticleOut(BaseModel):
    id: int
    name: str
    stock: int

class OrderCreate(BaseModel):
    article_id: int
    email: EmailStr

class OrderOut(BaseModel):
    id: int
    article_id: int
    buyer_email: str
    created_at: str


def require_admin(creds: HTTPBasicCredentials = Depends(security)):
    ok_user = secrets.compare_digest(creds.username, settings.admin_user)
    ok_pass = secrets.compare_digest(creds.password, settings.admin_pass)
    if not (ok_user and ok_pass):
        raise HTTPException(status_code=401, detail="Unauthorized")
    return True


@app.on_event("startup")
def _startup():
    init_db()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/api/articles", response_model=list[ArticleOut])
def api_list_articles():
    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id, name, stock FROM {schema}.articles ORDER BY id")
            return cur.fetchall()


@app.get("/api/articles/{article_id}", response_model=ArticleOut)
def api_get_article(article_id: int):
    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id, name, stock FROM {schema}.articles WHERE id = %s", (article_id,))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Article not found")
            return row


@app.post("/api/admin/articles", response_model=ArticleOut, dependencies=[Depends(require_admin)])
def api_create_article(payload: ArticleCreate):
    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {schema}.articles (name, stock)
                VALUES (%s, %s)
                ON CONFLICT (name)
                DO UPDATE SET stock = {schema}.articles.stock + EXCLUDED.stock
                RETURNING id, name, stock
                """,
                (payload.name, payload.stock),
            )
            row = cur.fetchone()
            conn.commit()
            return row


@app.post("/api/orders", response_model=OrderOut)
def api_buy_article(payload: OrderCreate):
    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id, stock FROM {schema}.articles WHERE id=%s", (payload.article_id,))
            art = cur.fetchone()
            if not art:
                raise HTTPException(status_code=404, detail="Article not found")
            if art["stock"] <= 0:
                raise HTTPException(status_code=400, detail="Out of stock")

            cur.execute(
                f"UPDATE {schema}.articles SET stock = stock - 1 WHERE id=%s AND stock > 0 RETURNING id",
                (payload.article_id,),
            )
            if not cur.fetchone():
                conn.rollback()
                raise HTTPException(status_code=400, detail="Out of stock")

            cur.execute(
                f"""
                INSERT INTO {schema}.orders (article_id, buyer_email)
                VALUES (%s, %s)
                RETURNING id, article_id, buyer_email, created_at
                """,
                (payload.article_id, str(payload.email)),
            )
            order = cur.fetchone()
            conn.commit()

    order["created_at"] = str(order["created_at"])
    return order


@app.get("/", response_class=HTMLResponse)
def page_home(request: Request, q: str | None = None):
    schema = settings.db_schema
    q_clean = (q or "").strip()
    with get_conn() as conn:
        with conn.cursor() as cur:
            if q_clean:
                cur.execute(
                    f"""
                    SELECT id, name, stock
                    FROM {schema}.articles
                    WHERE name ILIKE %s
                    ORDER BY id
                    """,
                    (f"%{q_clean}%",),
                )
            else:
                cur.execute(f"SELECT id, name, stock FROM {schema}.articles ORDER BY id")
            articles = cur.fetchall()

    return templates.TemplateResponse(
        "index.html",
        {"request": request, "articles": articles, "q": q_clean},
    )


@app.get("/article/{article_id}", response_class=HTMLResponse)
def page_article(article_id: int, request: Request):
    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id, name, stock FROM {schema}.articles WHERE id=%s", (article_id,))
            article = cur.fetchone()

    if not article:
        raise HTTPException(status_code=404, detail="Article not found")

    return templates.TemplateResponse("article.html", {"request": request, "article": article})


@app.post("/buy/{article_id}")
def page_buy(article_id: int, email: str = Form(...)):
    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(f"SELECT id, name, stock FROM {schema}.articles WHERE id=%s", (article_id,))
            art = cur.fetchone()
            if not art:
                raise HTTPException(status_code=404, detail="Article not found")
            if art["stock"] <= 0:
                raise HTTPException(status_code=400, detail="Out of stock")

            cur.execute(
                f"UPDATE {schema}.articles SET stock = stock - 1 WHERE id=%s AND stock > 0 RETURNING id",
                (article_id,),
            )
            if not cur.fetchone():
                conn.rollback()
                raise HTTPException(status_code=400, detail="Out of stock")

            cur.execute(
                f"INSERT INTO {schema}.orders (article_id, buyer_email) VALUES (%s, %s)",
                (article_id, email),
            )
            conn.commit()

    send_order_mail(email, art["name"])
    return RedirectResponse(url=f"/article/{article_id}", status_code=303)

@app.get("/admin", response_class=HTMLResponse)
def page_admin(request: Request, message: str | None = None):
    return templates.TemplateResponse("admin.html", {"request": request, "message": message})


@app.post("/admin/create")
def admin_create(name: str = Form(...), stock: int = Form(...), admin_pass: str = Form(...)):
    if admin_pass != settings.admin_pass:
        return RedirectResponse(url="/admin?message=Mot+de+passe+incorrect", status_code=303)

    schema = settings.db_schema
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                f"""
                INSERT INTO {schema}.articles (name, stock)
                VALUES (%s, %s)
                ON CONFLICT (name)
                DO UPDATE SET stock = {schema}.articles.stock + EXCLUDED.stock
                """,
                (name, stock),
            )
            conn.commit()

    return RedirectResponse(url="/admin?message=Produit+ajouté", status_code=303)
