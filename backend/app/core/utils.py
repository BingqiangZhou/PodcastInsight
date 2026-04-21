"""Utility functions for the application.
通用工具函数
"""

import html
import logging
import random
import re


logger = logging.getLogger(__name__)


def sanitize_html(text: str, allow_tags: set | None = None) -> str:
    """Sanitize HTML content to prevent XSS attacks.

    This function escapes HTML tags and attributes, making the content safe
    to display in web browsers.

    Args:
        text: Raw text that may contain HTML content
        allow_tags: Deprecated compatibility parameter. Tags are always escaped.

    Returns:
        Sanitized text with HTML escaped

    Examples:
        >>> sanitize_html("<script>alert('xss')</script>Hello")
        '&lt;script&gt;alert(&#x27;xss&#x27;)&lt;/script&gt;Hello'

        >>> sanitize_html("<b>Bold</b> text", allow_tags={'b'})
        '&lt;b&gt;Bold&lt;/b&gt; text'

    """
    if not text:
        return text

    if allow_tags is not None:
        logger.debug("sanitize_html ignores allow_tags and escapes all HTML")

    return html.escape(text)


def filter_thinking_content(text: str) -> str:
    """Filter out <thinking> and special Chinese punctuation tags from AI model output.
    过滤掉 AI 模型输出中的 <thinking> 和中文标点标签及其内容

    This function removes thinking/reasoning content that some AI models include
    in their responses, ensuring only the final answer is stored.

    Supports:
    - <thinking>...</thinking> tags
    - <think>...</think> tags

    Args:
        text: Raw AI model response that may contain thinking tags
              可能包含 thinking 标签的 AI 模型原始响应

    Returns:
        Cleaned text with thinking content removed
        移除思考内容后的清理文本

    Examples:
        >>> filter_thinking_content("<thinking>Let me think...</thinking>Hello!")
        'Hello!'

        >>> filter_thinking_content("<think>Thought process</think>Answer")
        'Answer'

        >>> filter_thinking_content("No thinking tags here")
        'No thinking tags here'

    """
    if not text:
        return text

    original_length = len(text)

    # Regex patterns to match <thinking> and <think> tags
    # DOTALL flag makes . match newlines for multiline content
    # 只过滤明确的 AI 思考标签，避免误删正常内容
    patterns = [
        r"<thinking>.*?</thinking>",
        r"<think>.*?</think>",
    ]

    cleaned = text
    # Remove thinking tags and their content
    for pattern in patterns:
        cleaned = re.sub(pattern, "", cleaned, flags=re.DOTALL | re.IGNORECASE)

    # Clean up leading/trailing whitespace but preserve internal formatting
    # 只清理首尾空白，保留正文内部的换行和标点
    cleaned = cleaned.strip()

    if len(cleaned) != original_length:
        logger.debug(
            f"Filtered thinking content: {original_length} -> {len(cleaned)} chars",
        )

    return cleaned


def calculate_backoff(attempt: int, base_delay: float = 1.0) -> float:
    """Calculate backoff time with jitter for retry attempts."""
    backoff = base_delay * (2**attempt)
    jitter = random.uniform(0, 0.5 * backoff)
    return backoff + jitter
