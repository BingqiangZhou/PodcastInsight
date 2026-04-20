"""统一日志配置模块

功能:
1. 按日期分割的日志文件 (app-YYYY-MM-DD.log)
2. 专用错误日志文件 (app-YYYY-MM-DD_error.log)
3. 支持时区配置 (默认 Asia/Shanghai)
4. 统一的日志格式
"""

import logging
import logging.handlers
import os
import sys
from datetime import UTC, datetime, timedelta, timezone
from pathlib import Path
from zoneinfo import ZoneInfo


# 默认配置
DEFAULT_LOG_DIR = "logs"
DEFAULT_LOG_LEVEL = "INFO"
DEFAULT_RETENTION_DAYS = 30
DEFAULT_TIMEZONE = "Asia/Shanghai"

# 时区偏移量（小时）- 上海时区 UTC+8
SHANGHAI_OFFSET = 8


class TimezoneFormatter(logging.Formatter):
    """支持时区的日志格式化器（使用 zoneinfo 处理 DST）"""

    def __init__(self, fmt=None, datefmt=None, timezone_str=None):
        super().__init__(fmt=fmt, datefmt=datefmt)
        self._tz: timezone | ZoneInfo | None = None
        if timezone_str:
            try:
                self._tz = ZoneInfo(timezone_str)
            except Exception:
                # Fallback: try parsing UTC+X format
                if timezone_str.startswith("UTC"):
                    try:
                        offset = int(timezone_str.replace("UTC", "").replace("+", ""))
                        self._tz = timezone(timedelta(hours=offset))
                    except ValueError:
                        self._tz = ZoneInfo("Asia/Shanghai")
                else:
                    self._tz = ZoneInfo("Asia/Shanghai")

    def formatTime(self, record, datefmt=None):  # noqa: N802
        """格式化时间为指定时区"""
        ct = datetime.fromtimestamp(record.created, tz=UTC)
        if self._tz:
            ct = ct.astimezone(self._tz)
        s = ct.strftime(datefmt) if datefmt else ct.strftime("%Y-%m-%d %H:%M:%S")
        return s


def setup_logging(
    log_level: str = DEFAULT_LOG_LEVEL,
    log_dir: str = DEFAULT_LOG_DIR,
    retention_days: int = DEFAULT_RETENTION_DAYS,
    timezone: str = DEFAULT_TIMEZONE,
    app_name: str = "app",
) -> None:
    """配置应用日志系统

    Args:
        log_level: 日志级别 (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        log_dir: 日志目录路径
        retention_days: 日志保留天数
        timezone: 时区 (如 Asia/Shanghai)
        app_name: 应用名称，用于日志文件命名

    """
    # 创建日志目录
    log_path = Path(log_dir)
    log_path.mkdir(exist_ok=True, parents=True)

    # 获取日志级别
    level = getattr(logging, log_level.upper(), logging.INFO)

    # 日志格式
    log_format = "[%(asctime)s] [%(levelname)s] [%(name)s:%(lineno)d] %(message)s"
    date_format = "%Y-%m-%d %H:%M:%S"

    # 创建时区格式化器
    formatter = TimezoneFormatter(
        fmt=log_format,
        datefmt=date_format,
        timezone_str=timezone,
    )

    # 清除现有的 handlers
    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.setLevel(level)

    # 1. 控制台处理器 (使用彩色输出，如果可用)
    # Ensure UTF-8 encoding for console output (critical in Docker / Windows containers)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    # 2. 按日期分割的常规日志文件处理器
    # 文件名: logs/app-YYYY-MM-DD.log
    normal_log_file = log_path / f"{app_name}.log"
    file_handler = logging.handlers.TimedRotatingFileHandler(
        filename=str(normal_log_file),
        when="midnight",
        interval=1,
        backupCount=retention_days,
        encoding="utf-8",
    )
    # 设置文件名后缀为日期
    file_handler.suffix = "%Y-%m-%d"
    file_handler.setLevel(level)
    file_handler.setFormatter(formatter)
    root_logger.addHandler(file_handler)

    # 3. 专用错误日志文件处理器
    # 文件名: logs/app-YYYY-MM-DD_error.log
    error_log_file = log_path / f"{app_name}_error.log"
    error_handler = logging.handlers.TimedRotatingFileHandler(
        filename=str(error_log_file),
        when="midnight",
        interval=1,
        backupCount=retention_days,
        encoding="utf-8",
    )
    error_handler.suffix = "%Y-%m-%d"
    error_handler.setLevel(logging.ERROR)
    error_handler.setFormatter(formatter)
    root_logger.addHandler(error_handler)

    # 配置第三方库的日志级别 (减少噪音)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.error").setLevel(logging.ERROR)
    logging.getLogger("gunicorn.access").setLevel(logging.WARNING)
    logging.getLogger("gunicorn.error").setLevel(logging.ERROR)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
    logging.getLogger("celery").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)

    # 记录日志系统启动信息
    logger = logging.getLogger(__name__)
    logger.info(
        f"日志系统已初始化 - 级别: {log_level}, 目录: {log_dir}, 时区: {timezone}"
    )


def get_logger(name: str) -> logging.Logger:
    """获取命名的日志记录器

    Args:
        name: 日志记录器名称 (通常使用 __name__)

    Returns:
        logging.Logger: 配置好的日志记录器

    """
    return logging.getLogger(name)


def get_log_files(log_dir: str = DEFAULT_LOG_DIR, app_name: str = "app") -> dict:
    """获取当前日志文件列表

    Args:
        log_dir: 日志目录
        app_name: 应用名称

    Returns:
        dict: 包含 normal 和 error 日志文件列表

    """
    log_path = Path(log_dir)
    result = {
        "normal": [],
        "error": [],
    }

    if log_path.exists():
        # 获取常规日志文件
        for f in sorted(log_path.glob(f"{app_name}-*.log")):
            if not f.name.endswith("_error.log"):
                result["normal"].append(str(f))

        # 获取错误日志文件
        for f in sorted(log_path.glob(f"{app_name}_*-error.log")):
            result["error"].append(str(f))

    return result


# Read configuration from Settings
def setup_logging_from_env(app_name: str = "app") -> None:
    """Read logging configuration from application settings.

    Settings fields (with env variable fallbacks):
        LOG_LEVEL: Log level (default: INFO)
        LOG_DIR: Log directory (default: logs)
        LOG_RETENTION_DAYS: Log retention days (default: 30)
        TZ: Timezone (default: Asia/Shanghai)
    """
    from app.core.config import get_settings

    s = get_settings()
    log_level = getattr(s, "LOG_LEVEL", DEFAULT_LOG_LEVEL)
    log_dir = getattr(s, "LOG_DIR", DEFAULT_LOG_DIR)
    retention_days = getattr(s, "LOG_RETENTION_DAYS", DEFAULT_RETENTION_DAYS)
    timezone = os.getenv("TZ", DEFAULT_TIMEZONE)

    setup_logging(
        log_level=log_level,
        log_dir=log_dir,
        retention_days=retention_days,
        timezone=timezone,
        app_name=app_name,
    )


# 导出快捷函数
def create_logger(module_name: str) -> logging.Logger:
    """快捷函数：创建日志记录器"""
    return get_logger(module_name)


# 模块初始化时自动设置日志 (从环境变量)
