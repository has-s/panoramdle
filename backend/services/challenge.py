import random
from datetime import date, timedelta
from typing import List, Dict, Any, Optional
import logging

from backend.db import database
from backend.models.news import news
from backend.models.challenge import daily_challenge

logger = logging.getLogger(__name__)


async def get_daily_challenge(challenge_date: date) -> Optional[Dict[str, Any]]:
    """Get existing daily challenge for a specific date"""
    query = daily_challenge.select().where(daily_challenge.c.challenge_date == challenge_date)
    result = await database.fetch_one(query)

    if result:
        return {
            "challenge_date": str(result.challenge_date),
            "news": result.news_snapshot,
            "is_custom": result.is_custom
        }

    return None


async def get_used_news_ids(challenge_date: date, days: int = 7) -> List[str]:
    """Get news IDs used in challenges over the last N days"""
    start_date = challenge_date - timedelta(days=days)

    query = daily_challenge.select().where(
        (daily_challenge.c.challenge_date >= start_date) &
        (daily_challenge.c.challenge_date < challenge_date)
    )

    results = await database.fetch_all(query)

    used_ids = set()
    for result in results:
        news_list = result.news_snapshot
        for news_item in news_list:
            used_ids.add(news_item['id'])

    return list(used_ids)


async def get_available_news(exclude_ids: List[str] = None) -> List[Dict[str, Any]]:
    """Get all available news, optionally excluding specific IDs"""
    if exclude_ids:
        query = news.select().where(news.c.id.notin_(exclude_ids))
    else:
        query = news.select()

    results = await database.fetch_all(query)

    return [dict(row) for row in results]


async def generate_daily_challenge(challenge_date: date, moderator_id: Optional[int] = None) -> Dict[str, Any]:
    """
    Generate daily challenge for a specific date.
    Selects 10 random news, avoiding repeats from last 7 days.
    """
    existing = await get_daily_challenge(challenge_date)
    if existing:
        logger.info(f"Daily challenge for {challenge_date} already exists")
        return existing

    used_ids = await get_used_news_ids(challenge_date, days=7)
    logger.info(f"Found {len(used_ids)} news IDs used in last 7 days")

    available = await get_available_news(exclude_ids=used_ids)
    logger.info(f"Available news count: {len(available)}")

    if len(available) < 10:
        logger.warning(f"Not enough news ({len(available)}), allowing repeats")
        available = await get_available_news()

    if len(available) < 10:
        logger.error(f"Not enough news in database: {len(available)}/10")
        raise ValueError(f"Need at least 10 news, found only {len(available)}")

    selected = random.sample(available, 10)

    news_snapshot = []
    for item in selected:
        news_snapshot.append({
            "id": item["id"],
            "headline": item["headline"],
            "text": item["text"],
            "format": item["format"],
            "media_url": item["media_url"],
            "source_name": item["source_name"],
            "published_date": str(item["published_date"]) if item["published_date"] else None,
            "is_real": item["is_real"],
            "author_comment": item["author_comment"]
        })

    insert_query = daily_challenge.insert().values(
        challenge_date=challenge_date,
        news_snapshot=news_snapshot,
        created_by=moderator_id,
        is_custom=False
    )

    await database.execute(insert_query)

    logger.info(f"Generated daily challenge for {challenge_date} with {len(news_snapshot)} news")

    return {
        "challenge_date": str(challenge_date),
        "news": news_snapshot,
        "is_custom": False
    }