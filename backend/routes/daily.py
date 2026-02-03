from fastapi import APIRouter, Request, HTTPException, Form
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from datetime import date
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
    """Get today's daily challenge (auto-generates if doesn't exist)"""
    today = date.today()

    try:
        existing = await get_daily_challenge(today)

        if existing:
            logger.info(f"Returning existing challenge for {today}")
            return existing

        logger.info(f"Generating new challenge for {today}")
        challenge = await generate_daily_challenge(today)

        return challenge

    except ValueError as e:
        logger.error(f"Failed to generate challenge: {e}")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get daily challenge"
        )


@router.get("/api/daily/{challenge_date}")
async def get_challenge_by_date(challenge_date: date):
    """Get daily challenge for a specific date"""
    try:
        challenge = await get_daily_challenge(challenge_date)

        if not challenge:
            raise HTTPException(
                status_code=404,
                detail=f"No challenge found for {challenge_date}"
            )

        return challenge

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting challenge for {challenge_date}: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to get challenge"
        )


@router.post("/api/daily/submit")
async def submit_challenge_result(
    challenge_date: str = Form(...),
    correct_count: int = Form(...)
):
    """Submit challenge result and update aggregate statistics"""
    try:
        challenge_date_obj = date.fromisoformat(challenge_date)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format")

    if correct_count < 0 or correct_count > 10:
        raise HTTPException(status_code=400, detail="correct_count must be between 0 and 10")

    try:
        from backend.models.challenge import daily_challenge

        update_query = daily_challenge.update().where(
            daily_challenge.c.challenge_date == challenge_date_obj
        ).values(
            total_attempts=daily_challenge.c.total_attempts + 1,
            total_correct=daily_challenge.c.total_correct + correct_count
        )

        result = await database.execute(update_query)

        if result == 0:
            raise HTTPException(status_code=404, detail="Challenge not found for this date")

        query = daily_challenge.select().where(
            daily_challenge.c.challenge_date == challenge_date_obj
        )
        challenge = await database.fetch_one(query)

        average = challenge.total_correct / challenge.total_attempts if challenge.total_attempts > 0 else 0

        return {
            "success": True,
            "your_result": correct_count,
            "total_attempts": challenge.total_attempts,
            "average_correct": round(average, 1),
            "average_percentage": round((average / 10) * 100, 1)
        }

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error submitting result: {e}")
        raise HTTPException(status_code=500, detail="Failed to submit result")