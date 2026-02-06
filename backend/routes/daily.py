from fastapi import APIRouter, Request, HTTPException, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from datetime import date as date_type
import logging

from backend.db import database
from backend.services.challenge import generate_daily_challenge, get_daily_challenge

router = APIRouter()
tests = Jinja2Templates(directory="backend/tests")
logger = logging.getLogger(__name__)


@router.get("/", response_class=HTMLResponse)
async def daily_page(request: Request):
    return tests.TemplateResponse("test_daily.html", {"request": request})


@router.get("/api/daily")
async def get_today_challenge():
    today = date_type.today()
    try:
        existing = await get_daily_challenge(today)
        if existing:
            logger.info(f"Returning existing challenge for {today}")
            return existing

        logger.info(f"Generating new challenge for {today}")
        return await generate_daily_challenge(today)
    except ValueError as e:
        logger.error(f"Failed to generate challenge: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail="Failed to get daily challenge")


@router.get("/api/daily/stats")
async def get_daily_stats(date: str = None):
    date_obj = date_type.fromisoformat(date) if date else date_type.today()

    try:
        from backend.models.challenge import daily_challenge

        result = await database.fetch_one(
            daily_challenge.select().where(daily_challenge.c.challenge_date == date_obj)
        )

        if not result:
            return {"total_attempts": 0, "average_correct": 0, "average_percentage": 0}

        # Преобразуем в dict
        row = dict(result)
        total = row.get("total_attempts", 0)
        correct = row.get("total_correct", 0)
        avg = correct / total if total > 0 else 0

        return {
            "total_attempts": total,
            "average_correct": round(avg, 1),
            "average_percentage": round((avg / 10) * 100, 1)
        }
    except Exception as e:
        logger.error(f"Stats error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/api/daily/{challenge_date}")
async def get_challenge_by_date(challenge_date: date_type):
    try:
        challenge = await get_daily_challenge(challenge_date)
        if not challenge:
            raise HTTPException(status_code=404, detail=f"No challenge found for {challenge_date}")
        return challenge
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting challenge for {challenge_date}: {e}")
        raise HTTPException(status_code=500, detail="Failed to get challenge")


@router.post("/api/daily/submit")
async def submit_challenge_result(challenge_date: str = Form(...), correct_count: int = Form(...)):
    try:
        challenge_date_obj = date_type.fromisoformat(challenge_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format")

    if not 0 <= correct_count <= 10:
        raise HTTPException(status_code=400, detail="correct_count must be between 0 and 10")

    try:
        from backend.models.challenge import daily_challenge

        await database.execute(
            daily_challenge.update()
            .where(daily_challenge.c.challenge_date == challenge_date_obj)
            .values(
                total_attempts=daily_challenge.c.total_attempts + 1,
                total_correct=daily_challenge.c.total_correct + correct_count
            )
        )

        result = await database.fetch_one(
            daily_challenge.select().where(daily_challenge.c.challenge_date == challenge_date_obj)
        )

        if not result:
            raise HTTPException(status_code=404, detail="Challenge not found")

        row = dict(result)
        total = row.get("total_attempts", 0)
        correct = row.get("total_correct", 0)
        avg = correct / total if total > 0 else 0

        return {
            "success": True,
            "your_result": correct_count,
            "total_attempts": total,
            "total_correct": correct,
            "average_correct": round(avg, 1),
            "average_percentage": round((avg / 10) * 100, 1)
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Submit error: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to submit result")