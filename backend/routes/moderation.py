from fastapi import APIRouter, Request, Form, Depends
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
import logging
from datetime import datetime

from backend.db import database
from backend.models.auth import moderators
from backend.middleware import require_auth, require_admin, get_client_ip, revoke_all_sessions
from backend.services.auth import log_action, hash_password, verify_password

router = APIRouter()
tests = Jinja2Templates(directory="backend/tests")
logger = logging.getLogger(__name__)


@router.get("/moderation/", response_class=HTMLResponse)
async def moderation_home(request: Request, moderator: dict = Depends(require_auth)):
    return tests.TemplateResponse("test_moderation.html", {"request": request})


@router.get("/api/users/me")
async def get_current_user(moderator: dict = Depends(require_auth)):
    return {
        "id": moderator["id"],
        "username": moderator["username"],
        "email": moderator["email"],
        "role": moderator["role"],
        "created_at": str(moderator["created_at"]),
        "last_login": str(moderator["last_login"]) if moderator["last_login"] else None
    }


@router.post("/api/users/change-password")
async def change_own_password(
        request: Request,
        moderator: dict = Depends(require_auth),
        old_password: str = Form(...),
        new_password: str = Form(...),
):
    query = moderators.select().where(moderators.c.id == moderator["id"])
    user = await database.fetch_one(query)

    if not verify_password(old_password, user.password_hash):
        return JSONResponse(
            {"ok": False, "error": "Неверный старый пароль"},
            status_code=400
        )

    new_hash = hash_password(new_password)
    update_query = moderators.update().where(
        moderators.c.id == moderator["id"]
    ).values(password_hash=new_hash)

    await database.execute(update_query)

    await log_action(
        moderator_id=moderator["id"],
        action="change_password",
        target_type="moderator",
        target_id=str(moderator["id"]),
        ip_address=get_client_ip(request)
    )

    logger.info(f"Password changed for user: {moderator['username']}")

    return {"ok": True}


@router.post("/api/users/update-email")
async def update_own_email(
        request: Request,
        moderator: dict = Depends(require_auth),
        email: str = Form(...),
):
    update_query = moderators.update().where(
        moderators.c.id == moderator["id"]
    ).values(email=email if email.strip() else None)

    await database.execute(update_query)

    await log_action(
        moderator_id=moderator["id"],
        action="update_email",
        target_type="moderator",
        target_id=str(moderator["id"]),
        details={"new_email": email},
        ip_address=get_client_ip(request)
    )

    logger.info(f"Email updated for user: {moderator['username']}")

    return {"ok": True}


@router.get("/api/users/list")
async def list_users(admin: dict = Depends(require_admin)):
    query = moderators.select().where(
        moderators.c.status != 'deleted'
    ).order_by(moderators.c.created_at.desc())

    users = await database.fetch_all(query)

    return [
        {
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "role": user.role,
            "status": user.status,
            "created_at": str(user.created_at),
            "last_login": str(user.last_login) if user.last_login else None
        }
        for user in users
    ]


@router.post("/api/users/create")
async def create_user(
        request: Request,
        admin: dict = Depends(require_admin),
        username: str = Form(...),
        password: str = Form(...),
        email: str = Form(""),
        role: str = Form("moderator"),
        force_overwrite: str = Form("false"),
):
    check_query = moderators.select().where(moderators.c.username == username)
    existing = await database.fetch_one(check_query)

    if existing:
        if existing.status == 'deleted':
            if force_overwrite == "false":
                return {
                    "conflict": True,
                    "deleted_user": {
                        "id": existing.id,
                        "username": existing.username,
                        "email": existing.email,
                        "created_at": str(existing.created_at),
                        "role": existing.role
                    },
                    "message": "Найден удалённый пользователь с таким же именем"
                }
            else:
                timestamp = int(datetime.utcnow().timestamp())
                update_query = moderators.update().where(
                    moderators.c.id == existing.id
                ).values(
                    username=f"{existing.username}_{timestamp}",
                    email=f"{existing.email}_{timestamp}" if existing.email else None
                )
                await database.execute(update_query)
        else:
            return JSONResponse(
                {"ok": False, "error": "Пользователь с таким username уже существует"},
                status_code=400
            )

    password_hash = hash_password(password)

    insert_query = moderators.insert().values(
        username=username,
        password_hash=password_hash,
        email=email if email.strip() else None,
        role=role,
        status='active',
        created_by=admin["id"]
    )

    new_id = await database.execute(insert_query)

    await log_action(
        moderator_id=admin["id"],
        action="create_moderator",
        target_type="moderator",
        target_id=str(new_id),
        details={"username": username, "role": role},
        ip_address=get_client_ip(request)
    )

    logger.info(f"User created by {admin['username']}: {username}")

    return {"ok": True, "id": new_id}


@router.post("/api/users/{user_id}/restore")
async def restore_deleted_user(
        user_id: int,
        request: Request,
        admin: dict = Depends(require_admin),
        new_password: str = Form(None),
):
    check_query = moderators.select().where(moderators.c.id == user_id)
    user = await database.fetch_one(check_query)

    if not user:
        return JSONResponse(
            {"ok": False, "error": "Пользователь не найден"},
            status_code=404
        )

    if user.status != 'deleted':
        return JSONResponse(
            {"ok": False, "error": "Пользователь не удалён"},
            status_code=400
        )

    values = {"status": "active"}

    if new_password:
        values["password_hash"] = hash_password(new_password)

    update_query = moderators.update().where(
        moderators.c.id == user_id
    ).values(**values)

    await database.execute(update_query)

    await log_action(
        moderator_id=admin["id"],
        action="restore_moderator",
        target_type="moderator",
        target_id=str(user_id),
        details={"target_username": user.username},
        ip_address=get_client_ip(request)
    )

    logger.info(f"User restored by {admin['username']}: {user.username}")

    return {"ok": True, "message": f"User '{user.username}' restored"}


@router.post("/api/users/{user_id}/reset-password")
async def reset_user_password(
        user_id: int,
        request: Request,
        admin: dict = Depends(require_admin),
        new_password: str = Form(...),
):
    if user_id == admin["id"]:
        return JSONResponse(
            {"ok": False, "error": "Используйте функцию смены пароля для себя"},
            status_code=400
        )

    check_query = moderators.select().where(moderators.c.id == user_id)
    user = await database.fetch_one(check_query)

    if not user:
        return JSONResponse(
            {"ok": False, "error": "Пользователь не найден"},
            status_code=404
        )

    if user.status == 'deleted':
        return JSONResponse(
            {"ok": False, "error": "Нельзя сбросить пароль удалённому пользователю"},
            status_code=400
        )

    new_hash = hash_password(new_password)
    update_query = moderators.update().where(
        moderators.c.id == user_id
    ).values(password_hash=new_hash)

    await database.execute(update_query)

    await log_action(
        moderator_id=admin["id"],
        action="reset_password",
        target_type="moderator",
        target_id=str(user_id),
        details={"target_username": user.username},
        ip_address=get_client_ip(request)
    )

    logger.info(f"Password reset by {admin['username']} for user: {user.username}")

    return {"ok": True}


@router.post("/api/users/{user_id}/deactivate")
async def deactivate_user(
        user_id: int,
        request: Request,
        admin: dict = Depends(require_admin),
):
    if user_id == admin["id"]:
        return JSONResponse(
            {"ok": False, "error": "Нельзя деактивировать самого себя"},
            status_code=400
        )

    check_query = moderators.select().where(moderators.c.id == user_id)
    user = await database.fetch_one(check_query)

    if not user:
        return JSONResponse(
            {"ok": False, "error": "Пользователь не найден"},
            status_code=404
        )

    if user.status == 'deleted':
        return JSONResponse(
            {"ok": False, "error": "Нельзя деактивировать удалённого пользователя"},
            status_code=400
        )

    update_query = moderators.update().where(
        moderators.c.id == user_id
    ).values(status='inactive')

    await database.execute(update_query)

    # Удаляем все сессии пользователя
    await revoke_all_sessions(user_id)

    await log_action(
        moderator_id=admin["id"],
        action="deactivate_moderator",
        target_type="moderator",
        target_id=str(user_id),
        details={"target_username": user.username},
        ip_address=get_client_ip(request)
    )

    logger.info(f"User deactivated by {admin['username']}: {user.username}")

    return {"ok": True}


@router.post("/api/users/{user_id}/activate")
async def activate_user(
        user_id: int,
        request: Request,
        admin: dict = Depends(require_admin),
):
    check_query = moderators.select().where(moderators.c.id == user_id)
    user = await database.fetch_one(check_query)

    if not user:
        return JSONResponse(
            {"ok": False, "error": "Пользователь не найден"},
            status_code=404
        )

    if user.status == 'deleted':
        return JSONResponse(
            {"ok": False, "error": "Нельзя активировать удалённого пользователя. Используйте 'Восстановить'."},
            status_code=400
        )

    update_query = moderators.update().where(
        moderators.c.id == user_id
    ).values(status='active')

    await database.execute(update_query)

    await log_action(
        moderator_id=admin["id"],
        action="activate_moderator",
        target_type="moderator",
        target_id=str(user_id),
        ip_address=get_client_ip(request)
    )

    return {"ok": True}


@router.delete("/api/users/{user_id}")
async def delete_user(
        user_id: int,
        request: Request,
        admin: dict = Depends(require_admin),
):
    if user_id == admin["id"]:
        return JSONResponse(
            {"ok": False, "error": "Нельзя удалить самого себя"},
            status_code=400
        )

    check_query = moderators.select().where(moderators.c.id == user_id)
    user = await database.fetch_one(check_query)

    if not user:
        return JSONResponse(
            {"ok": False, "error": "Пользователь не найден"},
            status_code=404
        )

    if user.status == 'deleted':
        return JSONResponse(
            {"ok": False, "error": "Пользователь уже удалён"},
            status_code=400
        )

    update_query = moderators.update().where(
        moderators.c.id == user_id
    ).values(status='deleted')

    await database.execute(update_query)

    # Удаляем все сессии пользователя
    await revoke_all_sessions(user_id)

    await log_action(
        moderator_id=admin["id"],
        action="delete_moderator",
        target_type="moderator",
        target_id=str(user_id),
        details={"target_username": user.username},
        ip_address=get_client_ip(request)
    )

    logger.info(f"User deleted (soft) by {admin['username']}: {user.username}")

    return {"ok": True}