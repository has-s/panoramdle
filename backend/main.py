from fastapi import FastAPI, Depends
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.openapi.docs import get_swagger_ui_html, get_redoc_html
from fastapi.openapi.utils import get_openapi
from fastapi.templating import Jinja2Templates
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from datetime import datetime
import logging

from backend.db import database
from backend.routes import daily, moderation, auth
from backend.middleware import require_admin, ForbiddenHTMLException

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await database.connect()
    logger.info("Database connected")
    yield
    await database.disconnect()
    logger.info("Database disconnected")


backend = FastAPI(
    title="Panoramdle",
    description="News quiz game - can you tell real news from fake?",
    version="1.0.0",
    lifespan=lifespan,
    docs_url=None,
    redoc_url=None,
    openapi_url=None
)

backend.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173"
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

templates = Jinja2Templates(directory="backend/templates")


@backend.exception_handler(ForbiddenHTMLException)
async def forbidden_html_handler(request, exc: ForbiddenHTMLException):
    return templates.TemplateResponse(
        "403.html",
        {
            "request": request,
            "username": exc.username,
            "role": exc.role
        },
        status_code=403
    )


backend.mount("/static", StaticFiles(directory="backend/static"), name="static")

backend.include_router(daily.router, tags=["Daily Quiz"])
backend.include_router(moderation.router, tags=["Moderation"])
backend.include_router(auth.router, tags=["Authentication"])


@backend.get("/health")
async def health_check():
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


@backend.get("/docs", include_in_schema=False)
async def get_documentation(admin: dict = Depends(require_admin)):
    return get_swagger_ui_html(
        openapi_url="/openapi.json",
        title=f"{backend.title} - API Documentation"
    )


@backend.get("/redoc", include_in_schema=False)
async def get_redoc(admin: dict = Depends(require_admin)):
    return get_redoc_html(
        openapi_url="/openapi.json",
        title=f"{backend.title} - API Documentation"
    )


@backend.get("/openapi.json", include_in_schema=False)
async def get_openapi_schema(admin: dict = Depends(require_admin)):
    return get_openapi(
        title=backend.title,
        version=backend.version,
        description=backend.description,
        routes=backend.routes
    )