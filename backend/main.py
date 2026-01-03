from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
import uuid

from backend.db import database, news

@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    yield
    await database.disconnect()

backend = FastAPI(lifespan=lifespan)
tests = Jinja2Templates(directory="backend/tests")
templates = Jinja2Templates(directory="backend/templates")

backend.mount("/static", StaticFiles(directory="backend/static"), name="static")

@backend.get("/api/quiz")
async def quiz():
    query = """
    SELECT id, headline, text, format, is_real, media_url, source_name
    FROM news
    ORDER BY RANDOM()
    LIMIT 3
    """
    rows = await database.fetch_all(query)
    return [dict(row) for row in rows]


@backend.get("/", response_class=HTMLResponse)
async def quiz_page(request: Request):
    return tests.TemplateResponse("test_quiz.html", {"request": request})


@backend.get("/addnews", response_class=HTMLResponse)
async def addnews_page(request: Request):
    return tests.TemplateResponse("test_addnews.html", {"request": request})


# === проверка пароля ===
def check_password(password: str) -> bool:
    tomorrow = datetime.now().date() + timedelta(days=1)
    return password == tomorrow.strftime("%d.%m.%Y")


@backend.post("/api/auth")
async def auth(password: str = Form(...)):
    if check_password(password):
        return {"ok": True}
    return {"ok": False}


@backend.post("/api/addnews")
async def add_news(
    headline: str = Form(...),
    text: str | None = Form(None),
    format: str = Form(...),
    is_real: str = Form(...),
    media_url: str | None = Form(None),
    source_name: str | None = Form(None),
    password: str = Form(...),
):
    if not check_password(password):
        return JSONResponse({"error": "Invalid password"}, status_code=403)
    is_real_bool = is_real.lower() == "true"

    query = news.insert().values(
        id=str(uuid.uuid4()),
        headline=headline,
        text=text,
        format=format,
        is_real=is_real_bool,
        media_url=media_url,
        source_name=source_name,
    )
    await database.execute(query)
    return {"ok": True}