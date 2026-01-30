import bcrypt
import uuid
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
import logging

from backend.db import database
from backend.models.auth import moderators, sessions, audit_log

logger = logging.getLogger(__name__)


def hash_password(password: str) -> str:
    salt = bcrypt.gensalt(rounds=12)
    password_hash = bcrypt.hashpw(password.encode('utf-8'), salt)
    return password_hash.decode('utf-8')


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(password.encode('utf-8'), password_hash.encode('utf-8'))
    except Exception as e:
        logger.error(f"Password verification error: {e}")
        return False


async def create_moderator(
        username: str,
        password: str,
        email: Optional[str] = None,
        role: str = "moderator",
        created_by_id: Optional[int] = None
) -> Optional[int]:
    try:
        password_hash = hash_password(password)

        query = moderators.insert().values(
            username=username,
            password_hash=password_hash,
            email=email,
            role=role,
            created_by=created_by_id
        )

        moderator_id = await database.execute(query)
        logger.info(f"Moderator created: {username} (ID: {moderator_id})")

        await log_action(
            moderator_id=created_by_id,
            action="create_moderator",
            target_type="moderator",
            target_id=str(moderator_id),
            details={"username": username, "role": role}
        )

        return moderator_id
    except Exception as e:
        logger.error(f"Error creating moderator: {e}")
        return None


async def authenticate(username: str, password: str) -> Optional[Dict[str, Any]]:
    try:
        query = moderators.select().where(
            (moderators.c.username == username) &
            (moderators.c.is_active == True)
        )
        moderator = await database.fetch_one(query)

        if not moderator:
            logger.warning(f"Login attempt for non-existent user: {username}")
            return None

        if not verify_password(password, moderator.password_hash):
            logger.warning(f"Invalid password for user: {username}")
            return None

        update_query = moderators.update().where(
            moderators.c.id == moderator.id
        ).values(last_login=datetime.now())
        await database.execute(update_query)

        return dict(moderator)
    except Exception as e:
        logger.error(f"Authentication error: {e}")
        return None


async def create_session(
        moderator_id: int,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        duration_hours: int = 24
) -> str:
    session_id = str(uuid.uuid4())
    expires_at = datetime.now() + timedelta(hours=duration_hours)

    query = sessions.insert().values(
        id=session_id,
        moderator_id=moderator_id,
        expires_at=expires_at,
        ip_address=ip_address,
        user_agent=user_agent
    )

    await database.execute(query)
    logger.info(f"Session created for moderator {moderator_id}: {session_id}")

    return session_id


async def get_session(session_id: str) -> Optional[Dict[str, Any]]:
    try:
        query = sessions.select().where(
            (sessions.c.id == session_id) &
            (sessions.c.expires_at > datetime.now())
        )
        session = await database.fetch_one(query)

        if not session:
            return None

        mod_query = moderators.select().where(
            (moderators.c.id == session.moderator_id) &
            (moderators.c.is_active == True)
        )
        moderator = await database.fetch_one(mod_query)

        if not moderator:
            return None

        update_query = sessions.update().where(
            sessions.c.id == session_id
        ).values(last_activity=datetime.now())
        await database.execute(update_query)

        return {
            "session": dict(session),
            "moderator": dict(moderator)
        }
    except Exception as e:
        logger.error(f"Error getting session: {e}")
        return None


async def delete_session(session_id: str) -> bool:
    try:
        query = sessions.delete().where(sessions.c.id == session_id)
        await database.execute(query)
        logger.info(f"Session deleted: {session_id}")
        return True
    except Exception as e:
        logger.error(f"Error deleting session: {e}")
        return False


async def log_action(
        moderator_id: Optional[int],
        action: str,
        target_type: Optional[str] = None,
        target_id: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
        ip_address: Optional[str] = None
) -> None:
    try:
        query = audit_log.insert().values(
            moderator_id=moderator_id,
            action=action,
            target_type=target_type,
            target_id=target_id,
            details=details,
            ip_address=ip_address
        )
        await database.execute(query)
    except Exception as e:
        logger.error(f"Error logging action: {e}")