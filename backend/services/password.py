from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


def check_password(password: str) -> bool:
    """
    Проверка пароля по формуле: завтрашняя дата в формате DD.MM.YYYY
    """
    tomorrow = datetime.now().date() + timedelta(days=1)
    expected = tomorrow.strftime("%d.%m.%Y")
    logger.info(f"Expected password: {expected}, received: {password}")
    return password == expected
