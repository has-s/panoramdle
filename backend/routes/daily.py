from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from backend.db import database

router = APIRouter()
tests = Jinja2Templates(directory="backend/tests")


@router.get("/", response_class=HTMLResponse)
async def daily_page(request: Request):
    return tests.TemplateResponse("test_daily.html", {"request": request})


@router.get("/api/daily")
async def get_daily():
    query = """
    SELECT id, headline, text, format, is_real, media_url, source_name, published_date
    FROM news
    ORDER BY RANDOM()
    LIMIT 5
    """
    rows = await database.fetch_all(query)
    return [dict(row) for row in rows]