from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import JSONResponse
from datetime import date, datetime
import uuid
import logging
import json

from backend.db import database
from backend.models import news
from backend.models.auth import moderators
from backend.middleware import require_auth, get_client_ip
from backend.services.auth import log_action

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/api/news/add")
async def add_news(
        request: Request,
        moderator: dict = Depends(require_auth),
        headline: str = Form(...),
        text: str = Form(""),
        format: str = Form(...),
        is_real: str = Form(...),
        media_url: str = Form(""),
        source_name: str = Form(""),
        published_date: str = Form(""),
        author_comment: str = Form(""),
):
    logger.info(f"Moderator {moderator['username']} adding news: {headline}")

    is_real_bool = is_real.lower() == "true"
    text_value = text if text.strip() else None
    media_url_value = media_url if media_url.strip() else None
    source_name_value = source_name if source_name.strip() else None
    author_comment_value = author_comment if author_comment.strip() else None

    try:
        if published_date:
            published_date_value = date.fromisoformat(published_date)
        else:
            published_date_value = date.today()

        news_id = str(uuid.uuid4())

        query = news.insert().values(
            id=news_id,
            headline=headline,
            text=text_value,
            format=format,
            is_real=is_real_bool,
            media_url=media_url_value,
            source_name=source_name_value,
            published_date=published_date_value,
            author_comment=author_comment_value,
            created_by=moderator["id"],
        )
        await database.execute(query)

        await log_action(
            moderator_id=moderator["id"],
            action="create_news",
            target_type="news",
            target_id=news_id,
            details={
                "headline": headline,
                "is_real": is_real_bool,
                "format": format
            },
            ip_address=get_client_ip(request)
        )

        logger.info(f"News added by {moderator['username']}: {news_id}")
        return {"ok": True}
    except Exception as e:
        logger.error(f"Database error: {str(e)}")
        return JSONResponse({"error": str(e), "ok": False}, status_code=500)


async def _get_moderator_username(moderator_id: int) -> str:
    """Вспомогательная функция для получения username по moderator_id"""
    query = moderators.select().where(moderators.c.id == moderator_id)
    mod = await database.fetch_one(query)
    return mod.username if mod else "unknown"


async def _format_news_response(item):
    """Форматирует новость с информацией о создателе и редакторах"""
    # Получаем создателя
    creator_username = await _get_moderator_username(item.created_by) if item.created_by else None

    # Парсим историю редактирований
    edit_history = []
    editor_usernames = []

    if item.edit_history:
        try:
            edit_history = json.loads(item.edit_history) if isinstance(item.edit_history, str) else item.edit_history
        except:
            edit_history = []

    # Собираем уникальные редакторы (первое упоминание)
    seen = set()
    for edit in edit_history:
        mod_id = edit.get("moderator_id")
        if mod_id and mod_id not in seen:
            username = await _get_moderator_username(mod_id)
            editor_usernames.append(username)
            seen.add(mod_id)

    return {
        "id": item.id,
        "headline": item.headline,
        "text": item.text,
        "format": item.format,
        "is_real": item.is_real,
        "media_url": item.media_url,
        "source_name": item.source_name,
        "published_date": str(item.published_date) if item.published_date else None,
        "author_comment": item.author_comment,
        "created_at": str(item.created_at),
        "created_by": item.created_by,
        "creator_username": creator_username,
        "editors": editor_usernames,
    }


@router.get("/api/news/list")
async def list_news(moderator: dict = Depends(require_auth)):
    """Get list of all news for moderation"""
    query = news.select().order_by(news.c.created_at.desc())
    news_list = await database.fetch_all(query)

    return [await _format_news_response(item) for item in news_list]


@router.get("/api/news/{news_id}")
async def get_news(news_id: str, moderator: dict = Depends(require_auth)):
    """Get single news item by ID with edit history"""
    query = news.select().where(news.c.id == news_id)
    item = await database.fetch_one(query)

    if not item:
        return JSONResponse({"error": "News not found"}, status_code=404)

    return await _format_news_response(item)


@router.put("/api/news/{news_id}")
async def update_news(
        news_id: str,
        request: Request,
        moderator: dict = Depends(require_auth),
        headline: str = Form(...),
        text: str = Form(""),
        format: str = Form(...),
        is_real: str = Form(...),
        media_url: str = Form(""),
        source_name: str = Form(""),
        published_date: str = Form(""),
        author_comment: str = Form(""),
):
    """Update existing news item"""
    is_real_bool = is_real.lower() == "true"
    text_value = text if text.strip() else None
    media_url_value = media_url if media_url.strip() else None
    source_name_value = source_name if source_name.strip() else None
    author_comment_value = author_comment if author_comment.strip() else None

    try:
        if published_date:
            published_date_value = date.fromisoformat(published_date)
        else:
            published_date_value = date.today()

        # Получаем текущую историю
        get_query = news.select().where(news.c.id == news_id)
        current_item = await database.fetch_one(get_query)

        if not current_item:
            return JSONResponse({"error": "News not found"}, status_code=404)

        # Парсим историю редактирований
        try:
            edit_history = json.loads(current_item.edit_history) if isinstance(current_item.edit_history, str) else (
                        current_item.edit_history or [])
        except:
            edit_history = []

        # Добавляем новую запись в историю
        edit_record = {
            "moderator_id": moderator["id"],
            "edited_at": datetime.now().isoformat(),
        }
        edit_history.append(edit_record)

        # Обновляем новость
        update_query = news.update().where(news.c.id == news_id).values(
            headline=headline,
            text=text_value,
            format=format,
            is_real=is_real_bool,
            media_url=media_url_value,
            source_name=source_name_value,
            published_date=published_date_value,
            author_comment=author_comment_value,
            edit_history=json.dumps(edit_history),
        )
        await database.execute(update_query)

        await log_action(
            moderator_id=moderator["id"],
            action="update_news",
            target_type="news",
            target_id=news_id,
            details={"headline": headline},
            ip_address=get_client_ip(request)
        )

        logger.info(f"News updated by {moderator['username']}: {news_id}")
        return {"ok": True}
    except Exception as e:
        logger.error(f"Database error: {str(e)}")
        return JSONResponse({"error": str(e), "ok": False}, status_code=500)


@router.delete("/api/news/{news_id}")
async def delete_news(
        news_id: str,
        request: Request,
        moderator: dict = Depends(require_auth),
):
    """Delete news item"""
    try:
        delete_query = news.delete().where(news.c.id == news_id)
        await database.execute(delete_query)

        await log_action(
            moderator_id=moderator["id"],
            action="delete_news",
            target_type="news",
            target_id=news_id,
            ip_address=get_client_ip(request)
        )

        logger.info(f"News deleted by {moderator['username']}: {news_id}")
        return {"ok": True}
    except Exception as e:
        logger.error(f"Database error: {str(e)}")
        return JSONResponse({"error": str(e), "ok": False}, status_code=500)