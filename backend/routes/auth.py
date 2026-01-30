from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
import logging

from backend.services.auth import authenticate, create_session, delete_session, log_action
from backend.middleware.auth import get_current_moderator, require_auth, get_client_ip, get_user_agent

router = APIRouter()
tests = Jinja2Templates(directory="backend/tests")
logger = logging.getLogger(__name__)


@router.get("/moderation/login", response_class=HTMLResponse)
async def login_page(request: Request):
    moderator = await get_current_moderator(request)
    if moderator:
        return RedirectResponse(url="/moderation", status_code=302)

    return tests.TemplateResponse("test_login.html", {"request": request})


@router.post("/api/auth/login")
async def login(
        request: Request,
        username: str = Form(...),
        password: str = Form(...)
):
    ip_address = get_client_ip(request)
    user_agent = get_user_agent(request)

    moderator = await authenticate(username, password)

    if not moderator:
        await log_action(
            moderator_id=None,
            action="login_failed",
            details={"username": username},
            ip_address=ip_address
        )
        return JSONResponse(
            {"ok": False, "error": "Неверный логин или пароль"},
            status_code=401
        )

    session_id = await create_session(
        moderator_id=moderator["id"],
        ip_address=ip_address,
        user_agent=user_agent
    )

    await log_action(
        moderator_id=moderator["id"],
        action="login",
        ip_address=ip_address
    )

    logger.info(f"Moderator logged in: {username}")

    response = JSONResponse({"ok": True, "username": username})
    response.set_cookie(
        key="session_id",
        value=session_id,
        httponly=True,
        max_age=86400,
        samesite="lax"
    )

    return response


@router.post("/api/auth/logout")
async def logout(request: Request, moderator: dict = Depends(require_auth)):
    session_id = request.cookies.get("session_id")

    if session_id:
        await delete_session(session_id)

    await log_action(
        moderator_id=moderator["id"],
        action="logout",
        ip_address=get_client_ip(request)
    )

    logger.info(f"Moderator logged out: {moderator['username']}")

    response = JSONResponse({"ok": True})
    response.delete_cookie("session_id")

    return response


@router.get("/api/auth/me")
async def get_me(request: Request):
    moderator = await get_current_moderator(request)

    if not moderator:
        return JSONResponse({"authenticated": False}, status_code=401)

    return {
        "authenticated": True,
        "id": moderator["id"],
        "username": moderator["username"],
        "email": moderator["email"],
        "role": moderator["role"]
    }