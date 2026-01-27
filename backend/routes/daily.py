from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from backend.db import database

router = APIRouter()
tests = Jinja2Templates(directory="backend/tests")


@router.get("/", response_class=HTMLResponse)
async def quiz_page(request: Request):
    """Страница квиза (временная тестовая версия)"""
    return tests.TemplateResponse("test_quiz.html", {"request": request})


@router.get("/api/quiz")
async def get_quiz():
    """API: Получить 5 случайных новостей для квиза"""
    query = """
    SELECT id, headline, text, format, is_real, media_url, source_name, published_date
    FROM news
    ORDER BY RANDOM()
    LIMIT 5
    """
    rows = await database.fetch_all(query)
    return [dict(row) for row in rows]