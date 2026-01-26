from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
import uuid
import logging
from datetime import date

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

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


@backend.get("/", response_class=HTMLResponse)
async def quiz_page(request: Request):
    return tests.TemplateResponse("test_quiz.html", {"request": request})

@backend.get("/health")
async def health_check():
    """Health check endpoint для мониторинга"""
    try:
        await database.execute("SELECT 1")
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "database": "connected"
        }
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return JSONResponse(
            {"status": "unhealthy", "error": str(e)},
            status_code=503
        )

@backend.get("/addnews", response_class=HTMLResponse)
async def addnews_page(request: Request):
    return tests.TemplateResponse("test_addnews.html", {"request": request})


def check_password(password: str) -> bool:
    tomorrow = datetime.now().date() + timedelta(days=1)
    expected = tomorrow.strftime("%d.%m.%Y")
    logger.info(f"Expected password: {expected}, received: {password}")
    return password == expected


@backend.post("/api/auth")
async def auth(password: str = Form(...)):
    if check_password(password):
        return {"ok": True}
    return {"ok": False}


@backend.get("/api/quiz")
async def quiz():
    query = """
    SELECT id, headline, text, format, is_real, media_url, source_name, published_date
    FROM news
    ORDER BY RANDOM()
    LIMIT 5
    """
    rows = await database.fetch_all(query)
    return [dict(row) for row in rows]


@backend.post("/api/addnews")
async def add_news(
        password: str = Form(...),
        headline: str = Form(...),
        text: str = Form(""),
        format: str = Form(...),
        is_real: str = Form(...),
        media_url: str = Form(""),
        source_name: str = Form(""),
        published_date: str = Form(""),
):
    logger.info(f"Received request: password={password}, headline={headline}, format={format}, is_real={is_real}")

    if not check_password(password):
        logger.warning("Invalid password attempt")
        return JSONResponse({"error": "Invalid password", "ok": False}, status_code=403)

    is_real_bool = is_real.lower() == "true"

    text_value = text if text.strip() else None
    media_url_value = media_url if media_url.strip() else None
    source_name_value = source_name if source_name.strip() else None

    try:
        if published_date:
            published_date_value = date.fromisoformat(published_date)
        else:
            published_date_value = date.today()

        query = news.insert().values(
            id=str(uuid.uuid4()),
            headline=headline,
            text=text_value,
            format=format,
            is_real=is_real_bool,
            media_url=media_url_value,
            source_name=source_name_value,
            published_date=published_date_value,
        )
        await database.execute(query)
        logger.info("News added successfully")
        return {"ok": True}
    except Exception as e:
        logger.error(f"Database error: {str(e)}")
        return JSONResponse({"error": str(e), "ok": False}, status_code=500)