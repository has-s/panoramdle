from fastapi import APIRouter, Request, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from datetime import date
import uuid
import logging

from backend.db import database
from backend.models.news import news
from backend.services.password import check_password

router = APIRouter()
tests = Jinja2Templates(directory="backend/tests")
logger = logging.getLogger(__name__)


@router.get("/addnews", response_class=HTMLResponse)
async def addnews_page(request: Request):
    """Страница добавления новости (временная тестовая версия)"""
    return tests.TemplateResponse("test_addnews.html", {"request": request})


@router.post("/api/auth")
async def auth(password: str = Form(...)):
    """API: Проверка пароля для доступа к модерации"""
    if check_password(password):
        return {"ok": True}
    return {"ok": False}


@router.post("/api/addnews")
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
    """API: Добавить новую новость"""
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