from fastapi import Request, HTTPException, status
from fastapi.templating import Jinja2Templates
from typing import Optional, Dict, Any
import logging

from backend.services.auth import get_session

logger = logging.getLogger(__name__)
templates = Jinja2Templates(directory="backend/templates")


class ForbiddenHTMLException(Exception):
    def __init__(self, username: str, role: str):
        self.username = username
        self.role = role


async def get_current_moderator(request: Request) -> Optional[Dict[str, Any]]:
    session_id = request.cookies.get("session_id")

    if not session_id:
        return None

    session_data = await get_session(session_id)

    if not session_data:
        return None

    return session_data["moderator"]


async def require_auth(request: Request) -> Dict[str, Any]:
    moderator = await get_current_moderator(request)

    if not moderator:
        accept_header = request.headers.get("accept", "")

        if "text/html" in accept_header:
            raise HTTPException(
                status_code=status.HTTP_307_TEMPORARY_REDIRECT,
                headers={"Location": f"/moderation/login?next={request.url.path}"}
            )

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated"
        )

    return moderator


async def require_admin(request: Request) -> Dict[str, Any]:
    moderator = await get_current_moderator(request)

    if not moderator:
        accept_header = request.headers.get("accept", "")

        if "text/html" in accept_header:
            raise HTTPException(
                status_code=status.HTTP_307_TEMPORARY_REDIRECT,
                headers={"Location": f"/moderation/login?next={request.url.path}"}
            )

        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated"
        )

    if moderator["role"] != "admin":
        accept_header = request.headers.get("accept", "")

        if "text/html" in accept_header:
            raise ForbiddenHTMLException(
                username=moderator["username"],
                role=moderator["role"]
            )

        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )

    return moderator


def get_client_ip(request: Request) -> str:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()

    real_ip = request.headers.get("X-Real-IP")
    if real_ip:
        return real_ip

    if request.client:
        return request.client.host

    return "unknown"


def get_user_agent(request: Request) -> str:
    return request.headers.get("User-Agent", "unknown")