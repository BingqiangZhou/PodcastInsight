"""
自定义 JSON 编码器

处理 datetime 序列化，确保时间戳带有时区信息
"""

import json
from datetime import UTC, datetime
from json import JSONEncoder
from typing import Any

from fastapi.responses import JSONResponse


class CustomJSONResponse(JSONResponse):
    """自定义 JSON 响应类，使用自定义编码器处理 datetime"""

    # 显式声明 media_type 包含 charset=utf-8
    media_type = "application/json; charset=utf-8"

    def render(self, content: Any) -> bytes:
        return json.dumps(
            content,
            ensure_ascii=False,
            allow_nan=False,
            indent=None,
            separators=(",", ":"),
            cls=CustomJSONEncoder,
        ).encode("utf-8")


class CustomJSONEncoder(JSONEncoder):
    """
    自定义 JSON 编码器

    - datetime 对象序列化为带时区信息的 ISO 8601 格式
    - 其他类型使用默认编码
    """

    def default(self, obj: Any) -> Any:
        # 处理 datetime 对象
        if isinstance(obj, datetime):
            # 如果 datetime 是 naive（没有时区信息），假设它是 UTC
            if obj.tzinfo is None:
                # 添加 UTC 时区信息
                obj = obj.replace(tzinfo=UTC)
            # 序列化为 ISO 格式（会包含时区信息，如 +00:00）
            return obj.isoformat()

        # 调用父类处理其他类型
        return super().default(obj)


def datetime_to_iso_format(dt: datetime) -> str:
    """
    将 datetime 转换为带时区信息的 ISO 格式字符串

    Args:
        dt: datetime 对象

    Returns:
        ISO 8601 格式字符串（带时区信息）
    """
    if dt.tzinfo is None:
        # 如果没有时区信息，假设是 UTC
        dt = dt.replace(tzinfo=UTC)
    return dt.isoformat()


def parse_datetime_from_iso(iso_string: str) -> datetime:
    """
    从 ISO 格式字符串解析 datetime

    Args:
        iso_string: ISO 8601 格式字符串

    Returns:
        datetime 对象
    """
    # Python 的 fromisoformat 可以处理带时区的 ISO 字符串
    # 但对于 Python 3.10 以下，需要做一些处理
    try:
        return datetime.fromisoformat(iso_string)
    except ValueError:
        # 如果字符串以 Z 结尾（UTC），替换为 +00:00
        if iso_string.endswith('Z'):
            return datetime.fromisoformat(iso_string.replace('Z', '+00:00'))
        raise
