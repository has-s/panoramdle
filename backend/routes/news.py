from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import JSONResponse
from datetime import date
import uuid
import logging

from backend.db import database
from backend.models import news
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


@router.get("/api/news/list")
async def list_news(moderator: dict = Depends(require_auth)):
    """Get list of all news for moderation"""
    query = news.select().order_by(news.c.created_at.desc())
    news_list = await database.fetch_all(query)

    return [
        {
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
        }
        for item in news_list
    ]


@router.get("/api/news/{news_id}")
async def get_news(news_id: str, moderator: dict = Depends(require_auth)):
    """Get single news item by ID"""
    query = news.select().where(news.c.id == news_id)
    item = await database.fetch_one(query)

    if not item:
        return JSONResponse({"error": "News not found"}, status_code=404)

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
    }


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

        update_query = news.update().where(news.c.id == news_id).values(
            headline=headline,
            text=text_value,
            format=format,
            is_real=is_real_bool,
            media_url=media_url_value,
            source_name=source_name_value,
            published_date=published_date_value,
            author_comment=author_comment_value,
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