"""
AI Model Testing Utilities

Provides functions for testing AI model configurations and validating API keys.
Extracted from services.py for better separation of concerns.
"""

import logging
import os
import re
import time
from typing import Any

import aiohttp

from app.core.config import settings
from app.core.utils import filter_thinking_content, sanitize_html
from app.domains.ai.models import AIModelConfig, ModelType
from app.domains.ai.schemas import APIKeyValidationResponse


logger = logging.getLogger(__name__)


async def test_transcription_model(
    model: AIModelConfig, api_key: str, test_data: dict[str, Any] | None = None
) -> str:
    """
    测试转录模型
    使用实际的音频文件进行测试，并与期望文本对比
    """
    from difflib import SequenceMatcher

    # 获取测试资源路径
    current_dir = os.path.dirname(os.path.abspath(__file__))
    test_resources_dir = os.path.join(
        os.path.dirname(os.path.dirname(current_dir)), "core", "test_resources"
    )

    example_txt_path = os.path.join(test_resources_dir, "example.txt")
    example_mp3_path = os.path.join(test_resources_dir, "example.mp3")

    # 读取期望文本
    if not os.path.exists(example_txt_path):
        return "⚠️ 测试文件缺失: example.txt 未找到"

    with open(example_txt_path, encoding="utf-8") as f:
        expected_text = f.read().strip()

    # 检查音频文件是否存在
    if not os.path.exists(example_mp3_path):
        return "⚠️ 测试文件缺失: example.mp3 未找到，无法进行实际测试"

    # 进行实际的转录测试
    try:
        headers = {"Authorization": f"Bearer {api_key}"}

        timeout = aiohttp.ClientTimeout(total=60)  # 转录可能需要更长时间

        async with aiohttp.ClientSession(timeout=timeout) as session:
            with open(example_mp3_path, "rb") as audio_file:
                data = aiohttp.FormData()
                data.add_field(
                    "file",
                    audio_file,
                    filename="example.mp3",
                    content_type="audio/mpeg",
                )
                data.add_field("model", model.model_id)
                data.add_field("language", "zh")  # 中文

                # 根据provider选择不同的API端点
                if model.provider == "openai":
                    api_endpoint = "https://api.openai.com/v1/audio/transcriptions"
                else:
                    # 对于其他提供商，使用数据库中存储的完整API URL
                    api_endpoint = model.api_url

                async with session.post(
                    api_endpoint, headers=headers, data=data
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        return (
                            f"❌ API 调用失败: {response.status} - {error_text[:200]}"
                        )

                    result = await response.json()

                    if "text" not in result:
                        return "❌ API 响应格式错误: 未包含 'text' 字段"

                    transcribed_text = result["text"].strip()

                    # 清理文本：去除标点、空格、表情符号等
                    def clean_text(text):
                        # 只保留中文字符、英文字母和数字
                        cleaned = re.sub(r"[^\u4e00-\u9fa5a-zA-Z0-9]", "", text)
                        return cleaned.lower()

                    expected_clean = clean_text(expected_text)
                    transcribed_clean = clean_text(transcribed_text)

                    # 计算相似度
                    similarity = SequenceMatcher(
                        None, expected_clean, transcribed_clean
                    ).ratio()
                    similarity_percent = similarity * 100

                    # 判断是否通过测试
                    passed = similarity_percent >= 90

                    result_parts = [
                        f"{'✅' if passed else '❌'} 转录测试{'通过' if passed else '失败'}",
                        f"\n期望文本: {expected_text}",
                        f"\n转录结果: {transcribed_text}",
                        f"\n相似度: {similarity_percent:.1f}%",
                        "\n阈值: 90.0%",
                    ]

                    return "".join(result_parts)

    except aiohttp.ClientError as e:
        return f"❌ 网络错误: {str(e)}"
    except Exception as e:
        return f"❌ 测试失败: {str(e)}"


async def test_text_generation_model(
    model: AIModelConfig, api_key: str, test_data: dict[str, Any] | None = None
) -> str:
    """测试文本生成模型"""
    # 修复：如果 test_data 为 None，使用空字典
    if test_data is None:
        test_data = {}

    # Use configured test prompt or allow custom prompt
    default_prompt = settings.ASSISTANT_TEST_PROMPT
    test_prompt = test_data.get("prompt", default_prompt)

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    data = {
        "model": model.model_id,
        "messages": [{"role": "user", "content": test_prompt}],
        "max_tokens": 50,
        "temperature": model.get_temperature_float() or 0.7,
    }

    timeout = aiohttp.ClientTimeout(total=model.timeout_seconds)

    async with (
        aiohttp.ClientSession(timeout=timeout) as session,
        session.post(
            f"{model.api_url}/chat/completions", headers=headers, json=data
        ) as response,
    ):
        if response.status != 200:
            error_text = await response.text()
            raise Exception(f"API error: {response.status} - {error_text}")

        result = await response.json()
        if "choices" not in result or not result["choices"]:
            raise Exception("Invalid response from API")

        raw_content = result["choices"][0]["message"]["content"].strip()

        # Filter out thinking tags in test results as well
        # 测试结果中也过滤掉 thinking 标签
        # First filter thinking content, then sanitize HTML
        cleaned_content = filter_thinking_content(raw_content)
        safe_content = sanitize_html(cleaned_content)

        return safe_content


async def validate_api_key(
    api_url: str, api_key: str, model_id: str | None, model_type: ModelType
) -> APIKeyValidationResponse:
    """验证API密钥"""
    start_time = time.time()
    result = None
    error_message = None

    try:
        if model_type == ModelType.TRANSCRIPTION:
            # 简单验证转录服务连接
            result = "Transcription endpoint format seems correct (Actual validation requires audio upload)"

        else:  # TEXT_GENERATION
            # 1. 尝试标准 Bearer Token
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            }

            # 确保URL不以/结尾
            base_url = api_url.rstrip("/")
            # 如果URL已经包含 v1/chat/completions，则使用原URL，否则追加
            if "chat/completions" in base_url:
                target_url = base_url
            else:
                target_url = f"{base_url}/chat/completions"

            data = {
                "model": model_id or "gpt-3.5-turbo",
                "messages": [{"role": "user", "content": "Hello"}],
            }

            timeout = aiohttp.ClientTimeout(total=600)

            logger.info(
                f"Validating API key against URL: {target_url} with model: {model_id}"
            )

            async with aiohttp.ClientSession(timeout=timeout) as session:
                try:
                    async with session.post(
                        target_url, headers=headers, json=data
                    ) as response:
                        logger.info(f"First request status: {response.status}")
                        if response.status == 200:
                            res_json = await response.json()
                            if "choices" in res_json and res_json["choices"]:
                                result = res_json["choices"][0]["message"]["content"]
                                logger.info(
                                    f"Validation successful, got result: {result}"
                                )
                            else:
                                result = "Connection successful but no content returned"
                                logger.info(
                                    "Validation successful but no content returned"
                                )
                        elif response.status in [401, 403, 400, 404]:
                            # 2. 失败则尝试 api-key header (Azure/MIMO style)
                            logger.info(
                                f"Standard auth failed ({response.status}), retrying with api-key header"
                            )
                            headers = {
                                "api-key": api_key,
                                "Content-Type": "application/json",
                            }
                            async with session.post(
                                target_url, headers=headers, json=data
                            ) as response2:
                                logger.info(
                                    f"Second request status: {response2.status}"
                                )
                                if response2.status == 200:
                                    res_json = await response2.json()
                                    if "choices" in res_json and res_json["choices"]:
                                        result = res_json["choices"][0]["message"][
                                            "content"
                                        ]
                                        logger.info(
                                            f"Validation successful via api-key, got result: {result}"
                                        )
                                    else:
                                        result = "Connection successful (via api-key) but no content returned"
                                        logger.info(
                                            "Validation successful via api-key but no content returned"
                                        )
                                else:
                                    text = await response2.text()
                                    error_message = f"Validation failed: {response.status} (Bearer) / {response2.status} (api-key) - {text}"
                                    logger.error(
                                        f"Validation failed with api-key: {error_message}"
                                    )
                        else:
                            text = await response.text()
                            error_message = (
                                f"Validation failed: {response.status} - {text}"
                            )
                            logger.error(
                                f"Validation failed with Bearer: {error_message}"
                            )
                except aiohttp.ClientConnectionError as e:
                    # Specific connection errors (DNS, connection refused, etc.)
                    error_message = f"Connection error: Unable to connect to {target_url}. Please check the URL and network connection. Details: {type(e).__name__}: {str(e)}"
                    logger.error(
                        f"ClientConnectionError to {target_url}: {type(e).__name__}: {str(e)}",
                        exc_info=True,
                    )
                except aiohttp.ClientResponseError as e:
                    # HTTP response errors
                    error_message = f"HTTP error: {e.status} - {e.message}"
                    logger.error(
                        f"ClientResponseError to {target_url}: {e.status} - {e.message}",
                        exc_info=True,
                    )
                except aiohttp.ClientPayloadError as e:
                    # Payload encoding/decoding errors
                    error_message = (
                        f"Payload error: Invalid response data. Details: {str(e)}"
                    )
                    logger.error(
                        f"ClientPayloadError to {target_url}: {str(e)}", exc_info=True
                    )
                except TimeoutError:
                    # Timeout errors
                    error_message = f"Timeout error: Request to {target_url} timed out after 600 seconds"
                    logger.error(
                        f"TimeoutError connecting to {target_url}", exc_info=True
                    )
                except aiohttp.ClientError as e:
                    # Other aiohttp client errors
                    error_message = f"Client error: {type(e).__name__}: {str(e)}"
                    logger.error(
                        f"ClientError to {target_url}: {type(e).__name__}: {str(e)}",
                        exc_info=True,
                    )
                except Exception as e:
                    # Catch-all for unexpected errors
                    error_message = f"Unexpected error: {type(e).__name__}: {str(e)}"
                    logger.error(
                        f"Unexpected error to {target_url}: {type(e).__name__}: {str(e)}",
                        exc_info=True,
                    )

    except Exception as e:
        error_message = f"System error: {str(e)}"
        logger.error(f"System error in validate_api_key: {str(e)}", exc_info=True)

    response_time = (time.time() - start_time) * 1000

    logger.info(
        f"Validation completed in {response_time}ms, valid: {error_message is None}"
    )

    return APIKeyValidationResponse(
        valid=error_message is None,
        error_message=error_message,
        test_result=result,
        response_time_ms=response_time,
    )
