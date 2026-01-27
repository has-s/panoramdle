from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from datetime import datetime
import logging

from backend.db import database
from backend.routes import daily, moderation

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Управление жизненным циклом приложения"""
    await database.connect()
    logger.info("Database connected")
    yield
    await database.disconnect()
    logger.info("Database disconnected")


# Инициализация FastAPI приложения
backend = FastAPI(
    title="Panoramdle",
    description="News quiz game - can you tell real news from fake?",
    version="1.0.0",
    lifespan=lifespan
)

# Подключение статических файлов
backend.mount("/static", StaticFiles(directory="backend/static"), name="static")

# Подключение роутеров
backend.include_router(daily.router, tags=["Daily Quiz"])
backend.include_router(moderation.router, tags=["Moderation"])


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