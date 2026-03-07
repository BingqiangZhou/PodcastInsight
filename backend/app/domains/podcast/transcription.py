"""
鎾闊抽杞綍鏈嶅姟

鎻愪緵闊抽涓嬭浇銆佹牸寮忚浆鎹€佹枃浠跺垏鍓层€丄PI杞綍鍜岀粨鏋滃悎骞剁殑瀹屾暣鍔熻兘
"""

import asyncio
import logging
import os
import re
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import aiofiles
import aiohttp
import ffmpeg
from fastapi import HTTPException, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ValidationError
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.models import (
    PodcastEpisode,
    TranscriptionStatus,
    TranscriptionStep,
    TranscriptionTask,
)
from app.domains.podcast.services.summary_generation_service import (
    PodcastSummaryGenerationService as DatabaseBackedAISummaryService,
)
from app.domains.podcast.transcription_state import _progress_throttle


logger = logging.getLogger(__name__)


def log_with_timestamp(level: str, message: str, task_id: int = None):
    """
    杈撳嚭甯︽椂闂存埑鐨勬棩蹇?

    Args:
        level: 鏃ュ織绾у埆 (INFO, WARNING, ERROR, DEBUG)
        message: 鏃ュ織娑堟伅
        task_id: 浠诲姟ID锛堝彲閫夛級
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    task_info = f"[Task:{task_id}] " if task_id is not None else ""
    formatted_message = f"{timestamp} {task_info}{message}"

    if level == "INFO":
        logger.info(formatted_message)
    elif level == "WARNING":
        logger.warning(formatted_message)
    elif level == "ERROR":
        logger.error(formatted_message)
    elif level == "DEBUG":
        logger.debug(formatted_message)
    else:
        logger.info(formatted_message)


@dataclass
class AudioChunk:
    """闊抽鍒嗙墖淇℃伅"""

    index: int
    file_path: str
    start_time: float  # 寮€濮嬫椂闂达紙绉掞級
    duration: float  # 鏃堕暱锛堢锛?
    file_size: int  # 鏂囦欢澶у皬锛堝瓧鑺傦級
    transcript: str | None = None  # 杞綍缁撴灉


class AudioDownloader:
    """闊抽鏂囦欢涓嬭浇鍣?"""

    def __init__(self, timeout: int = 300, chunk_size: int = 8192):
        self.timeout = timeout
        self.chunk_size = chunk_size
        self.session: aiohttp.ClientSession | None = None

    async def __aenter__(self):
        """寮傛涓婁笅鏂囩鐞嗗櫒鍏ュ彛"""
        connector = aiohttp.TCPConnector(limit=10, limit_per_host=5)
        timeout = aiohttp.ClientTimeout(total=self.timeout)
        # 浣跨敤瀹屾暣鐨勬祻瑙堝櫒澶撮儴浠ョ粫杩?CDN 闃叉姢锛圕loudflare绛夛級
        headers = {
            "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1",
            "Sec-Fetch-Dest": "document",
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Sec-Fetch-User": "?1",
            "Cache-Control": "max-age=0",
        }
        self.session = aiohttp.ClientSession(
            connector=connector, timeout=timeout, headers=headers
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """寮傛涓婁笅鏂囩鐞嗗櫒鍑哄彛"""
        if self.session:
            await self.session.close()

    async def download_file(
        self, url: str, destination: str, progress_callback=None
    ) -> tuple[str, int]:
        """
        涓嬭浇鏂囦欢鍒版寚瀹氫綅缃?

        Args:
            url: 涓嬭浇URL
            destination: 淇濆瓨璺緞
            progress_callback: 杩涘害鍥炶皟鍑芥暟

        Returns:
            Tuple[str, int]: (鏂囦欢璺緞, 鏂囦欢澶у皬)
        """
        if not self.session:
            raise RuntimeError("AudioDownloader must be used as async context manager")

        # 纭繚鐩綍瀛樺湪
        os.makedirs(os.path.dirname(destination), exist_ok=True)

        # 澶勭悊 lizhi.fm 鐨?CDN URL
        original_url = url
        if "cdn.lizhi.fm" in url:
            url = url.replace("cdn.lizhi.fm", "cdn.gzlzfm.com")
            logger.info(
                f"馃攧 [CDN REPLACEMENT] Replaced CDN URL: {original_url[:80]}... -> {url[:80]}..."
            )

        # 鍑嗗璇锋眰澶?
        request_headers = dict(self.session.headers)
        # 涓?lizhi.fm 娣诲姞 Referer
        if "lizhi.fm" in original_url or "lizhi.fm" in url or "gzlzfm.com" in url:
            request_headers["Referer"] = "https://www.lizhi.fm/"
            logger.info(
                "馃搵 [HEADERS] Added Referer for lizhi.fm: https://www.lizhi.fm/"
            )

        # 杈撳嚭璇锋眰澶翠俊鎭敤浜庤皟璇?
        logger.info(f"馃摛 [HTTP REQUEST] URL: {url}")
        logger.info(f"馃摛 [HTTP REQUEST] Headers: {request_headers}")

        try:
            async with self.session.get(url, headers=request_headers) as response:
                # 鈩癸笍 杈撳嚭鍝嶅簲澶翠俊鎭?
                logger.info(f"鈩癸笍 [Response Headers] {dict(response.headers)}")

                if response.status != 200:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Failed to download audio file: HTTP {response.status}",
                    )

                # 鑾峰彇鏂囦欢澶у皬
                content_length = response.headers.get("content-length")
                total_size = int(content_length) if content_length else 0

                # 涓嬭浇鏂囦欢
                downloaded = 0
                first_chunk_logged = False
                async with aiofiles.open(destination, "wb") as f:
                    async for chunk in response.content.iter_chunked(self.chunk_size):
                        # 鈩癸笍 杈撳嚭绗竴涓猚hunk鐨勫墠200瀛楄妭
                        if not first_chunk_logged:
                            preview = chunk[:200]
                            logger.info(
                                f"鈩癸笍 [Response Body Preview] First 200 bytes: {preview}"
                            )
                            first_chunk_logged = True

                        await f.write(chunk)
                        downloaded += len(chunk)

                        # 璋冪敤杩涘害鍥炶皟
                        if progress_callback and total_size > 0:
                            progress = (downloaded / total_size) * 100
                            await progress_callback(progress)

                logger.info(
                    f"Successfully downloaded file to {destination}, size: {downloaded} bytes"
                )
                return destination, downloaded

        except asyncio.TimeoutError as err:
            raise HTTPException(
                status_code=status.HTTP_408_REQUEST_TIMEOUT, detail="Download timeout"
            ) from err
        except Exception as e:
            logger.error(f"Download failed: {str(e)}")
            # 娓呯悊閮ㄥ垎涓嬭浇鐨勬枃浠?
            if os.path.exists(destination):
                os.remove(destination)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Download failed: {str(e)}",
            ) from e

    async def download_file_with_fallback(
        self, url: str, destination: str, progress_callback=None
    ) -> tuple[str, int]:
        """
        鏂囦欢涓嬭浇锛堢洿鎺ヤ娇鐢?aiohttp锛屾棤鍥為€€锛?

        Args:
            url: 涓嬭浇URL
            destination: 淇濆瓨璺緞
            progress_callback: 杩涘害鍥炶皟鍑芥暟

        Returns:
            Tuple[str, int]: (鏂囦欢璺緞, 鏂囦欢澶у皬)

        Raises:
            HTTPException: 濡傛灉涓嬭浇澶辫触
        """
        # 鐩存帴浣跨敤 aiohttp 涓嬭浇
        logger.info(f"馃摜 [DOWNLOAD] Starting download for: {url[:100]}...")
        try:
            file_path, file_size = await self.download_file(
                url, destination, progress_callback
            )
            logger.info(f"鉁?[DOWNLOAD] Download succeeded: {file_size} bytes")
            return file_path, file_size

        except Exception as e:
            logger.error(f"鉂?[DOWNLOAD] Download failed: {type(e).__name__}: {str(e)}")
            if isinstance(e, HTTPException):
                raise
            else:
                raise HTTPException(
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                    detail=f"Download failed: {str(e)}",
                ) from e


# Note: Browser fallback download has been removed.
# The download now uses only aiohttp with proper headers and retry logic.


class AudioConverter:
    """闊抽鏍煎紡杞崲鍣?"""

    @staticmethod
    async def convert_to_mp3(
        input_path: str, output_path: str, progress_callback=None
    ) -> tuple[str, float]:
        """
        灏嗛煶棰戞枃浠惰浆鎹负MP3鏍煎紡

        Args:
            input_path: 杈撳叆鏂囦欢璺緞
            output_path: 杈撳嚭MP3鏂囦欢璺緞
            progress_callback: 杩涘害鍥炶皟鍑芥暟

        Returns:
            Tuple[str, float]: (杈撳嚭鏂囦欢璺緞, 杞崲鑰楁椂)
        """
        start_time = time.time()

        try:
            # 楠岃瘉杈撳叆鏂囦欢瀛樺湪
            if not os.path.exists(input_path):
                raise FileNotFoundError(f"Input file not found: {input_path}")

            input_size = os.path.getsize(input_path)
            logger.info(
                f"馃帶 [CONVERT] Starting conversion: {input_path} ({input_size / 1024 / 1024:.2f} MB) -> {output_path}"
            )

            # 纭繚杈撳嚭鐩綍瀛樺湪
            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # 鏋勫缓FFmpeg鍛戒护
            ffmpeg_proc = (
                ffmpeg.input(input_path)
                .output(
                    output_path,
                    acodec="mp3",
                    ac=1,  # 鍗曞０閬?
                    ar="16000",  # 16kHz閲囨牱鐜?
                    ab="64k",  # 64kbps姣旂壒鐜?
                    f="mp3",
                )
                .overwrite_output()
                .global_args(
                    "-loglevel", "error"
                )  # Changed from 'quiet' to 'error' for debugging
            )

            # 鎵ц杞崲
            if progress_callback:
                await progress_callback(0)

            # 浣跨敤瀛愯繘绋嬫墽琛孎Fmpeg
            cmd = ffmpeg_proc.compile()
            logger.debug(f"馃帶 [CONVERT] FFmpeg command: {' '.join(cmd)}")

            process = await asyncio.create_subprocess_exec(
                *cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
            )

            stdout, stderr = await process.communicate()

            if process.returncode != 0:
                error_msg = (
                    stderr.decode("utf-8", errors="replace")
                    if stderr
                    else "Unknown FFmpeg error"
                )
                logger.error(
                    f"馃帶 [CONVERT] FFmpeg failed with return code {process.returncode}"
                )
                logger.error(f"馃帶 [CONVERT] FFmpeg stderr: {error_msg}")
                raise RuntimeError(
                    f"FFmpeg conversion failed (code {process.returncode}): {error_msg}"
                )

            # Verify output file was created
            if not os.path.exists(output_path):
                raise RuntimeError(
                    f"FFmpeg completed successfully but output file not found: {output_path}"
                )

            output_size = os.path.getsize(output_path)
            if output_size == 0:
                os.remove(output_path)
                raise RuntimeError(f"FFmpeg created empty output file: {output_path}")

            if progress_callback:
                await progress_callback(100)

            duration = time.time() - start_time
            logger.info(
                f"鉁?[CONVERT] Successfully converted {input_path} to {output_path}"
            )
            logger.info(
                f"鉁?[CONVERT] Input: {input_size / 1024 / 1024:.2f} MB -> Output: {output_size / 1024 / 1024:.2f} MB, Time: {duration:.2f}s"
            )

            return output_path, duration

        except Exception as e:
            logger.error(
                f"鉂?[CONVERT] Audio conversion failed: {type(e).__name__}: {str(e)}"
            )
            logger.error(
                f"鉂?[CONVERT] Input: {input_path} (exists: {os.path.exists(input_path)}), Output: {output_path} (exists: {os.path.exists(output_path)})"
            )
            # 娓呯悊杈撳嚭鏂囦欢锛堜繚鐣欑敤浜庤皟璇曪級
            if os.path.exists(output_path):
                try:
                    os.remove(output_path)
                    logger.debug(
                        f"馃Ч [CONVERT] Removed partial output file: {output_path}"
                    )
                except Exception as cleanup_error:
                    logger.warning(
                        f"鈿狅笍 [CONVERT] Failed to remove partial output: {cleanup_error}"
                    )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Audio conversion failed: {str(e)}",
            ) from e


class AudioSplitter:
    """闊抽鏂囦欢鍒囧壊鍣?"""

    @staticmethod
    async def split_mp3_by_duration(
        input_path: str,
        output_dir: str,
        chunk_duration_seconds: int = 300,
        progress_callback=None,
    ) -> list[AudioChunk]:
        """
        灏哅P3鏂囦欢鎸夋椂闂撮暱搴﹀垏鍓叉垚鐗囨锛堟帹鑽愮敤浜庤浆褰曪級

        Args:
            input_path: 杈撳叆MP3鏂囦欢璺緞
            output_dir: 杈撳嚭鐩綍
            chunk_duration_seconds: 姣忎釜鐗囨鐨勬椂闀匡紙绉掞級锛岄粯璁?00绉掞紙5鍒嗛挓锛?
            progress_callback: 杩涘害鍥炶皟鍑芥暟

        Returns:
            List[AudioChunk]: 鍒囧壊鍚庣殑闊抽鐗囨鍒楄〃
        """
        try:
            # 纭繚杈撳嚭鐩綍瀛樺湪
            os.makedirs(output_dir, exist_ok=True)

            # 浣跨敤FFmpeg鑾峰彇闊抽鏃堕暱
            probe = ffmpeg.probe(input_path)
            duration = float(probe["streams"][0]["duration"])

            # 璁＄畻闇€瑕佸垏鍓茬殑娈垫暟
            num_chunks = max(
                1,
                int(duration // chunk_duration_seconds)
                + (1 if duration % chunk_duration_seconds > 0 else 0),
            )
            actual_chunk_duration = duration / num_chunks

            chunks = []
            base_name = os.path.splitext(os.path.basename(input_path))[0]

            for i in range(num_chunks):
                start_time = i * chunk_duration_seconds
                # 鏈€鍚庝竴娈电殑鏃堕暱鍙兘涓嶅悓
                end_time = min(start_time + chunk_duration_seconds, duration)
                segment_duration = end_time - start_time

                output_path = os.path.join(
                    output_dir, f"{base_name}_chunk_{i + 1:03d}.mp3"
                )

                # 浣跨敤FFmpeg鍒囧壊 - 浣跨敤鏃堕棿鍙傛暟鑰岄潪鏂囦欢澶у皬
                (
                    ffmpeg.input(input_path, ss=start_time, t=segment_duration)
                    .output(
                        output_path,
                        acodec="mp3",
                        ac=1,  # 鍗曞０閬?
                        ar="16000",  # 16kHz閲囨牱鐜?
                        ab="64k",  # 64kbps姣旂壒鐜?
                    )
                    .overwrite_output()
                    .global_args("-loglevel", "quiet")
                    .run()
                )

                # 鑾峰彇鍒囧壊鍚庣殑鏂囦欢澶у皬
                chunk_file_size = os.path.getsize(output_path)

                chunk = AudioChunk(
                    index=i + 1,
                    file_path=output_path,
                    start_time=start_time,
                    duration=segment_duration,
                    file_size=chunk_file_size,
                )
                chunks.append(chunk)

                # 鏇存柊杩涘害
                if progress_callback:
                    progress = ((i + 1) / num_chunks) * 100
                    await progress_callback(progress)

            logger.info(
                f"Successfully split {input_path} into {len(chunks)} chunks by time ({chunk_duration_seconds}s each)"
            )
            return chunks

        except Exception as e:
            logger.error(f"Audio splitting by time failed: {str(e)}")
            # 娓呯悊宸插垱寤虹殑鏂囦欢
            for chunk in locals().get("chunks", []):
                if os.path.exists(chunk.file_path):
                    os.remove(chunk.file_path)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Audio splitting by time failed: {str(e)}",
            ) from e

    @staticmethod
    async def split_mp3(
        input_path: str,
        output_dir: str,
        chunk_size_mb: int = 10,
        progress_callback=None,
    ) -> list[AudioChunk]:
        """
        灏哅P3鏂囦欢鍒囧壊鎴愭寚瀹氬ぇ灏忕殑鐗囨

        Args:
            input_path: 杈撳叆MP3鏂囦欢璺緞
            output_dir: 杈撳嚭鐩綍
            chunk_size_mb: 姣忎釜鐗囨鐨勫ぇ灏忥紙MB锛?
            progress_callback: 杩涘害鍥炶皟鍑芥暟

        Returns:
            List[AudioChunk]: 鍒囧壊鍚庣殑闊抽鐗囨鍒楄〃
        """
        try:
            # 楠岃瘉杈撳叆鏂囦欢瀛樺湪
            if not os.path.exists(input_path):
                raise FileNotFoundError(f"Input file not found: {input_path}")

            input_size = os.path.getsize(input_path)
            logger.info(
                f"馃敧 [SPLIT] Starting split: {input_path} ({input_size / 1024 / 1024:.2f} MB) into {chunk_size_mb}MB chunks"
            )

            # 纭繚杈撳嚭鐩綍瀛樺湪
            os.makedirs(output_dir, exist_ok=True)
            logger.info(f"馃敧 [SPLIT] Output directory: {output_dir}")

            # 鑾峰彇鏂囦欢淇℃伅
            file_size = os.path.getsize(input_path)
            chunk_size_bytes = chunk_size_mb * 1024 * 1024

            # 浣跨敤FFmpeg鑾峰彇闊抽鏃堕暱
            try:
                probe = ffmpeg.probe(input_path)
                duration = float(probe["streams"][0]["duration"])
                logger.info(f"馃敧 [SPLIT] Input duration: {duration:.2f}s")
            except Exception as e:
                logger.error(f"馃敧 [SPLIT] FFmpeg probe failed: {e}")
                raise RuntimeError(f"Failed to probe input file: {e}") from e

            # 璁＄畻闇€瑕佸垏鍓茬殑娈垫暟
            num_chunks = max(1, (file_size + chunk_size_bytes - 1) // chunk_size_bytes)
            chunk_duration = duration / num_chunks

            logger.info(
                f"馃敧 [SPLIT] Will create {num_chunks} chunks, ~{chunk_duration:.2f}s each"
            )

            chunks = []
            base_name = os.path.splitext(os.path.basename(input_path))[0]

            for i in range(num_chunks):
                start_time = i * chunk_duration
                output_path = os.path.join(
                    output_dir, f"{base_name}_chunk_{i + 1:03d}.mp3"
                )

                logger.debug(
                    f"馃敧 [SPLIT] Creating chunk {i + 1}/{num_chunks}: {output_path} (start: {start_time:.2f}s, duration: {chunk_duration:.2f}s)"
                )

                # 浣跨敤FFmpeg鍒囧壊 - 鎹曡幏杈撳嚭鐢ㄤ簬璋冭瘯
                try:
                    # 鏋勫缓FFmpeg鍛戒护
                    ffmpeg_cmd = (
                        ffmpeg.input(input_path, ss=start_time, t=chunk_duration)
                        .output(output_path, c="copy")
                        .overwrite_output()
                        .global_args(
                            "-loglevel", "error"
                        )  # Changed from 'quiet' to 'error'
                        .compile()
                    )

                    # 浣跨敤瀛愯繘绋嬫墽琛屼互鎹曡幏閿欒
                    process = await asyncio.create_subprocess_exec(
                        *ffmpeg_cmd,
                        stdout=asyncio.subprocess.PIPE,
                        stderr=asyncio.subprocess.PIPE,
                    )

                    stdout, stderr = await process.communicate()

                    if process.returncode != 0:
                        error_msg = (
                            stderr.decode("utf-8", errors="replace")
                            if stderr
                            else "Unknown error"
                        )
                        raise RuntimeError(
                            f"FFmpeg split failed (code {process.returncode}): {error_msg}"
                        )

                except Exception as e:
                    logger.error(f"馃敧 [SPLIT] Failed to create chunk {i + 1}: {e}")
                    raise

                # 楠岃瘉杈撳嚭鏂囦欢琚垱寤?
                if not os.path.exists(output_path):
                    raise RuntimeError(
                        f"FFmpeg completed but output file not created: {output_path}"
                    )

                chunk_file_size = os.path.getsize(output_path)
                if chunk_file_size == 0:
                    os.remove(output_path)
                    raise RuntimeError(f"FFmpeg created empty chunk: {output_path}")

                chunk = AudioChunk(
                    index=i + 1,
                    file_path=output_path,
                    start_time=start_time,
                    duration=chunk_duration,
                    file_size=chunk_file_size,
                )
                chunks.append(chunk)

                logger.debug(
                    f"馃敧 [SPLIT] Created chunk {i + 1}: {chunk_file_size / 1024:.2f} KB"
                )

                # 鏇存柊杩涘害
                if progress_callback:
                    progress = ((i + 1) / num_chunks) * 100
                    await progress_callback(progress)

            total_output_size = sum(c.file_size for c in chunks)
            logger.info(
                f"鉁?[SPLIT] Successfully split {input_path} into {len(chunks)} chunks ({total_output_size / 1024 / 1024:.2f} MB total)"
            )
            return chunks

        except Exception as e:
            logger.error(
                f"鉂?[SPLIT] Audio splitting failed: {type(e).__name__}: {str(e)}"
            )
            logger.error(
                f"鉂?[SPLIT] Input: {input_path} (exists: {os.path.exists(input_path)}), Output dir: {output_dir}"
            )
            # 娓呯悊宸插垱寤虹殑鏂囦欢
            for chunk in locals().get("chunks", []):
                if os.path.exists(chunk.file_path):
                    try:
                        os.remove(chunk.file_path)
                        logger.debug(
                            f"馃Ч [SPLIT] Removed partial chunk: {chunk.file_path}"
                        )
                    except Exception as cleanup_error:
                        logger.warning(
                            f"鈿狅笍 [SPLIT] Failed to remove partial chunk: {cleanup_error}"
                        )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Audio splitting failed: {str(e)}",
            ) from e


class SiliconFlowTranscriber:
    """SiliconFlow API transcription service."""

    def __init__(self, api_key: str, api_url: str, max_concurrent: int = 4):
        self.api_key = api_key
        self.api_url = api_url
        self.max_concurrent = max_concurrent
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.session: aiohttp.ClientSession | None = None
        self._usage_stats = {"success": 0, "failure": 0}
        self._usage_stats_lock = asyncio.Lock()

    async def _record_usage(self, *, success: bool) -> None:
        key = "success" if success else "failure"
        async with self._usage_stats_lock:
            self._usage_stats[key] += 1

    async def __aenter__(self):
        """Async context manager entry."""
        connector = aiohttp.TCPConnector(limit=self.max_concurrent)
        timeout = aiohttp.ClientTimeout(total=600)
        self.session = aiohttp.ClientSession(
            connector=connector,
            timeout=timeout,
            headers={"Authorization": f"Bearer {self.api_key}"},
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.session:
            await self.session.close()

    async def transcribe_chunk(
        self,
        chunk: AudioChunk,
        model: str = "FunAudioLLM/SenseVoiceSmall",
    ) -> AudioChunk:
        """Transcribe a single audio chunk with retries."""

        async with self.semaphore:
            if not self.session:
                raise RuntimeError("Transcriber must be used as async context manager")

            max_retries = 3
            base_delay = 2

            for attempt in range(max_retries):
                chunk_start = time.time()
                try:
                    data = aiohttp.FormData()
                    data.add_field("model", model)
                    with open(chunk.file_path, "rb") as file_obj:
                        data.add_field(
                            "file",
                            file_obj.read(),
                            filename=os.path.basename(chunk.file_path),
                            content_type="audio/mpeg",
                        )

                    async with self.session.post(self.api_url, data=data) as response:
                        if response.status != 200:
                            error_text = await response.text()
                            await self._record_usage(success=False)
                            logger.error(
                                "Chunk %s API error on attempt %s: status=%s body=%s",
                                chunk.index,
                                attempt + 1,
                                response.status,
                                error_text,
                            )
                            if attempt < max_retries - 1:
                                await asyncio.sleep(base_delay * (2**attempt))
                                continue
                            chunk.transcript = None
                            return chunk

                        result = await response.json()
                        transcript = result.get("text", "")
                        await self._record_usage(success=True)
                        chunk.transcript = transcript

                        transcript_file = chunk.file_path.replace(".mp3", ".txt")
                        try:
                            async with aiofiles.open(
                                transcript_file, "w", encoding="utf-8"
                            ) as file_obj:
                                await file_obj.write(transcript)
                        except Exception as save_error:
                            logger.warning(
                                "Failed to persist transcript chunk %s: %s",
                                chunk.index,
                                save_error,
                            )

                        logger.info(
                            "Chunk %s completed in %.2fs",
                            chunk.index,
                            time.time() - chunk_start,
                        )
                        return chunk
                except Exception as exc:
                    await self._record_usage(success=False)
                    logger.error(
                        "Chunk %s attempt %s failed: %s",
                        chunk.index,
                        attempt + 1,
                        exc,
                    )
                    if attempt < max_retries - 1:
                        await asyncio.sleep(base_delay * (2**attempt))
                    else:
                        chunk.transcript = None
                        return chunk

            return chunk

    async def transcribe_chunks(
        self,
        chunks: list[AudioChunk],
        model: str = "FunAudioLLM/SenseVoiceSmall",
        progress_callback=None,
        ai_repo=None,
        config_db_id: int | None = None,
    ) -> list[AudioChunk]:
        """Transcribe chunks concurrently and persist usage in one DB commit."""
        start_time = time.time()
        self._usage_stats = {"success": 0, "failure": 0}

        tasks = [
            asyncio.create_task(self.transcribe_chunk(chunk, model)) for chunk in chunks
        ]

        results: list[AudioChunk] = []
        completed = 0
        for coro in asyncio.as_completed(tasks):
            try:
                results.append(await coro)
                completed += 1
                if progress_callback:
                    await progress_callback((completed / len(chunks)) * 100)
            except Exception as exc:
                logger.error("Unexpected chunk coroutine error: %s", exc)

        results.sort(key=lambda item: item.index)

        if ai_repo and config_db_id:
            try:
                await ai_repo.increment_usage_bulk(
                    config_db_id,
                    success_count=self._usage_stats["success"],
                    error_count=self._usage_stats["failure"],
                )
            except Exception as stats_error:
                logger.warning(
                    "Failed to persist aggregated usage stats: %s", stats_error
                )

        success_count = sum(1 for item in results if item.transcript is not None)
        logger.info(
            "Completed transcription of %s/%s chunks in %.2fs",
            success_count,
            len(chunks),
            time.time() - start_time,
        )
        return results


class PodcastTranscriptionService:
    """鎾杞綍涓绘湇鍔?"""

    def __init__(self, db: AsyncSession):
        self.db = db
        # 杩涘害缂撳瓨锛屽噺灏戞暟鎹簱鎿嶄綔棰戠巼
        self._progress_cache: dict[str, dict[str, float | str]] = {}
        self._task_progress_context_cache: dict[int, dict[str, Any]] = {}

        # Get path from settings - use absolute path if configured, otherwise resolve relative path
        temp_dir_config = getattr(
            settings, "TRANSCRIPTION_TEMP_DIR", "./temp/transcription"
        )
        storage_dir_config = getattr(
            settings, "TRANSCRIPTION_STORAGE_DIR", "./storage/podcasts"
        )

        # Use configured path directly (supports both absolute and relative)
        # In Docker, these will be absolute paths like /app/temp/transcription
        # In local dev, these will be relative paths that get resolved
        self.temp_dir = os.path.abspath(temp_dir_config)
        self.storage_dir = os.path.abspath(storage_dir_config)

        # Log for debugging (use debug level to reduce noise)
        logger.debug(
            f"馃搧 [TRANSCRIPTION] temp_dir = {self.temp_dir} (from config: {temp_dir_config})"
        )
        logger.debug(
            f"馃搧 [TRANSCRIPTION] storage_dir = {self.storage_dir} (from config: {storage_dir_config})"
        )
        logger.debug(f"馃搧 [TRANSCRIPTION] cwd = {os.getcwd()}")

        self.chunk_size_mb = getattr(settings, "TRANSCRIPTION_CHUNK_SIZE_MB", 10)
        self.max_threads = getattr(settings, "TRANSCRIPTION_MAX_THREADS", 4)
        self.min_chunk_success_ratio = float(
            getattr(settings, "TRANSCRIPTION_MIN_CHUNK_SUCCESS_RATIO", 0.6)
        )
        self.progress_commit_min_delta = float(
            getattr(settings, "TRANSCRIPTION_PROGRESS_COMMIT_MIN_DELTA", 5.0)
        )
        self.progress_commit_min_interval = float(
            getattr(settings, "TRANSCRIPTION_PROGRESS_COMMIT_MIN_INTERVAL_SECONDS", 3.0)
        )
        # API configuration is now dynamic, but we keep defaults for fallback
        self.default_api_url = getattr(
            settings,
            "TRANSCRIPTION_API_URL",
            "https://api.siliconflow.cn/v1/audio/transcriptions",
        )
        self.default_api_key = getattr(settings, "TRANSCRIPTION_API_KEY", None)

    def _get_episode_storage_path(self, episode: PodcastEpisode) -> str:
        """鑾峰彇鎾鍗曢泦鐨勫瓨鍌ㄨ矾寰?"""
        # 娓呯悊鎾鍚嶇О鍜屽垎闆嗗悕绉?
        podcast_name = self._sanitize_filename(episode.subscription.title)
        episode_name = self._sanitize_filename(episode.title)

        return os.path.join(self.storage_dir, podcast_name, episode_name)

    def _sanitize_filename(self, filename: str) -> str:
        """娓呯悊鏂囦欢鍚嶏紝绉婚櫎闈炴硶瀛楃"""
        import re

        # 绉婚櫎鎴栨浛鎹㈤潪娉曞瓧绗?
        filename = re.sub(r'[<>:"/\\|?*]', "", filename)
        filename = filename.replace(" ", "_")
        return filename[:100]  # 闄愬埗闀垮害

    async def update_task_progress(
        self,
        task_id: int,
        status: TranscriptionStatus,
        progress: float,
        message: str,
        error_message: str | None = None,
    ):
        """鏇存柊浠诲姟杩涘害"""
        update_data = {
            "status": status,
            "progress_percentage": progress,
            "updated_at": datetime.now(timezone.utc),
        }

        if error_message:
            update_data["error_message"] = error_message

        # 璁剧疆寮€濮嬫椂闂?
        if status == TranscriptionStatus.IN_PROGRESS and not await self._get_task_field(
            task_id, "started_at"
        ):
            update_data["started_at"] = datetime.now(timezone.utc)

        # 璁剧疆瀹屾垚鏃堕棿
        if status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            update_data["completed_at"] = datetime.now(timezone.utc)

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await self.db.execute(stmt)
        await self.db.commit()

        # 浣跨敤鑺傛祦鍣ㄥ噺灏戞棩蹇楄緭鍑?
        if _progress_throttle.should_log(task_id, str(status), progress):
            logger.info(
                f"Updated task {task_id}: status={status}, progress={progress:.1f}%"
            )

    async def _get_task_field(self, task_id: int, field: str):
        """鑾峰彇浠诲姟鐨勬寚瀹氬瓧娈?"""
        stmt = select(getattr(TranscriptionTask, field)).where(
            TranscriptionTask.id == task_id
        )
        result = await self.db.execute(stmt)
        return result.scalar()

    async def _update_task_progress_with_session(
        self,
        session: AsyncSession,
        task_id: int,
        step: TranscriptionStep,  # ?????step ?????status
        progress: float,
        message: str,
        error_message: str | None = None,
    ):
        """?????????????????????????????"""
        from app.domains.podcast.models import TranscriptionStatus

        cache_key = f"{task_id}_{step}"
        if cache_key not in self._progress_cache:
            self._progress_cache[cache_key] = {
                "last_db_update": 0.0,
                "last_db_update_at": 0.0,
                "last_log": 0.0,
            }

        cached = self._progress_cache[cache_key]
        progress_delta = abs(progress - cached["last_db_update"])
        now_mono = time.monotonic()
        last_db_update_at = float(cached.get("last_db_update_at", 0.0))
        interval_elapsed = now_mono - last_db_update_at

        if (
            progress_delta < self.progress_commit_min_delta
            and interval_elapsed < self.progress_commit_min_interval
            and int(progress) != 100
        ):
            return

        update_data = {
            "current_step": step,
            "progress_percentage": progress,
            "updated_at": datetime.now(timezone.utc),
        }

        if error_message:
            update_data["error_message"] = error_message

        context = self._task_progress_context_cache.get(task_id)
        if context is None:
            stmt_context = select(
                TranscriptionTask.started_at,
                TranscriptionTask.chunk_info,
            ).where(TranscriptionTask.id == task_id)
            context_row = (await session.execute(stmt_context)).one_or_none()
            started_at = context_row[0] if context_row else None
            chunk_info = context_row[1] if context_row else None
            context = {
                "started": bool(started_at),
                "chunk_info": chunk_info if isinstance(chunk_info, dict) else {},
                "last_debug_message": (
                    chunk_info.get("debug_message")
                    if isinstance(chunk_info, dict)
                    else None
                ),
            }
            self._task_progress_context_cache[task_id] = context

        if not context["started"]:
            update_data["started_at"] = datetime.now(timezone.utc)
            update_data["status"] = TranscriptionStatus.IN_PROGRESS
            context["started"] = True

        if message and message != context.get("last_debug_message"):
            next_chunk_info = dict(context.get("chunk_info") or {})
            next_chunk_info["debug_message"] = message
            update_data["chunk_info"] = next_chunk_info
            context["chunk_info"] = next_chunk_info
            context["last_debug_message"] = message

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await session.execute(stmt)
        await session.commit()

        cached["last_db_update"] = progress
        cached["last_db_update_at"] = now_mono

        log_delta = abs(progress - cached["last_log"])
        if log_delta >= 5.0 or int(progress) == 100:
            if int(progress) == 100:
                logger.info(f"??[PROGRESS] Task {task_id}: {step} - COMPLETED")
            else:
                logger.info(f"?? [PROGRESS] Task {task_id}: {step} - {progress:.1f}%")
            cached["last_log"] = progress

    async def _set_task_final_status(
        self,
        session: AsyncSession,
        task_id: int,
        status: TranscriptionStatus,  # COMPLETED ??FAILED
        error_message: str | None = None,
    ):
        """???????????????COMPLETED ??FAILED??"""
        update_data = {"status": status, "updated_at": datetime.now(timezone.utc)}

        if status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            update_data["completed_at"] = datetime.now(timezone.utc)

        if error_message:
            update_data["error_message"] = error_message

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await session.execute(stmt)
        await session.commit()

        self._task_progress_context_cache.pop(task_id, None)
        for progress_key in [
            key for key in self._progress_cache if key.startswith(f"{task_id}_")
        ]:
            self._progress_cache.pop(progress_key, None)

        logger.info(f"Set task {task_id} final status: {status}")

    async def create_transcription_task_record(
        self, episode_id: int, model: str | None = None, force: bool = False
    ) -> tuple[TranscriptionTask, int | None]:
        """
        鍒涘缓杞綍浠诲姟璁板綍锛堜笉绔嬪嵆鎵ц锛?

        Returns:
            Tuple[TranscriptionTask, Optional[int]]: (浠诲姟瀵硅薄, 妯″瀷閰嶇疆DB ID)
        """
        logger.info(
            f"馃幀 [TRANSCRIPTION PREPARE] episode_id={episode_id}, model={model}, force={force}"
        )

        # 妫€鏌ユ槸鍚﹀凡瀛樺湪杞綍浠诲姟
        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id
        )
        result = await self.db.execute(stmt)
        existing_task = result.scalar_one_or_none()

        if existing_task:
            logger.info(
                f"馃攧 [TRANSCRIPTION] Existing task found: id={existing_task.id}, status={existing_task.status}"
            )
            if force:
                # Force mode: delete existing task and create new one (regardless of status)
                logger.info(
                    f"馃棏锔?[TRANSCRIPTION] Force mode: deleting existing task {existing_task.id}"
                )
                await self.db.delete(existing_task)
                await self.db.flush()
                await (
                    self.db.commit()
                )  # Commit the delete to release the unique constraint
            elif existing_task.status not in [
                TranscriptionStatus.FAILED,
                TranscriptionStatus.CANCELLED,
            ]:
                # Task exists with non-failed/cancelled status and force=false: raise error
                logger.warning(
                    f"鈿狅笍 [TRANSCRIPTION] Task already exists with status {existing_task.status}"
                )
                raise ValidationError(
                    f"Transcription task already exists for episode {episode_id} with status {existing_task.status}. Use force=true to retry."
                )
            else:
                # Task exists with failed/cancelled status and force=false: delete it and create new one
                logger.info(
                    f"馃棏锔?[TRANSCRIPTION] Removing failed/cancelled task {existing_task.id} before creating new one"
                )
                await self.db.delete(existing_task)
                await self.db.flush()
                await (
                    self.db.commit()
                )  # Commit the delete to release the unique constraint
                logger.info(
                    "鉁?[TRANSCRIPTION] Failed/cancelled task removed, ready to create new one"
                )

        # 鑾峰彇鎾鍗曢泦淇℃伅
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if not episode:
            logger.error(f"鉂?[TRANSCRIPTION] Episode {episode_id} not found")
            raise ValidationError(f"Episode {episode_id} not found")

        logger.info(
            f"馃摵 [TRANSCRIPTION] Episode found: title='{episode.title}', audio_url='{episode.audio_url}'"
        )

        # 纭畾浣跨敤鐨勬ā鍨?
        ai_repo = AIModelConfigRepository(self.db)

        # 1. 濡傛灉鎸囧畾浜嗘ā鍨嬪悕绉帮紝灏濊瘯鏌ユ壘
        model_config = None
        if model:
            model_config = await ai_repo.get_by_name(model)
            logger.info(
                f"馃攳 [TRANSCRIPTION] Looking for model by name '{model}': {model_config is not None}"
            )
            # 妫€鏌ユ寚瀹氭ā鍨嬫槸鍚﹀瓨鍦ㄤ笖娲昏穬
            if (
                not model_config
                or not model_config.is_active
                or model_config.model_type != ModelType.TRANSCRIPTION
            ):
                raise ValidationError(
                    f"Transcription model '{model}' not found or not active"
                )

        # 2. 濡傛灉鏈寚瀹氭垨鏈壘鍒帮紝鎸変紭鍏堢骇鑾峰彇杞綍妯″瀷
        if not model_config:
            active_models = await ai_repo.get_active_models_by_priority(
                ModelType.TRANSCRIPTION
            )
            if active_models:
                model_config = active_models[0]  # 浣跨敤浼樺厛绾ф渶楂樼殑妯″瀷
                logger.info(
                    f"馃攳 [TRANSCRIPTION] Using highest priority model: {model_config.model_id} (priority={model_config.priority})"
                )
            else:
                # 濡傛灉娌℃湁鎵惧埌浠讳綍娲昏穬鐨勮浆褰曟ā鍨嬶紝鎶涘嚭閿欒
                raise ValidationError("No active transcription model found")

        # 纭畾鏈€缁堜娇鐢ㄧ殑妯″瀷ID瀛楃涓?(浼犻€掔粰API鐨刴odel鍙傛暟)
        transcription_model = model_config.model_id
        logger.info(f"馃 [TRANSCRIPTION] Final model to use: '{transcription_model}'")

        # 鍒涘缓鏂扮殑杞綍浠诲姟
        logger.info("馃摑 [TRANSCRIPTION] Creating TranscriptionTask in database...")
        task = TranscriptionTask(
            episode_id=episode_id,
            original_audio_url=episode.audio_url,
            chunk_size_mb=self.chunk_size_mb,
            model_used=transcription_model,  # 杩欓噷瀛樺偍鐨勬槸API妯″瀷ID (濡?whisper-1)锛屼笉鏄暟鎹簱ID
        )

        self.db.add(task)
        await self.db.commit()
        await self.db.refresh(task)

        logger.info(
            f"鉁?[TRANSCRIPTION] Task created in DB: id={task.id}, status={task.status}"
        )

        config_db_id = model_config.id if model_config else None
        return task, config_db_id

    async def start_transcription(
        self, episode_id: int, model: str | None = None, force: bool = False
    ) -> TranscriptionTask:
        """鍚姩杞綍浠诲姟"""
        # 1. 鍒涘缓浠诲姟璁板綍
        task, config_db_id = await self.create_transcription_task_record(
            episode_id, model=model, force=force
        )

        logger.info(
            f"馃幆 [TRANSCRIPTION] Task {task.id} created successfully. config_db_id={config_db_id}"
        )

        return task

    async def execute_transcription_task(
        self, task_id: int, session, config_db_id: int | None = None
    ):
        """鎵ц杞綍浠诲姟锛堝悗鍙拌繍琛岋級"""
        log_with_timestamp(
            "INFO", "馃幀 [EXECUTE START] Transcription task starting...", task_id
        )
        log_with_timestamp(
            "INFO", f"馃搵 [EXECUTE] config_db_id={config_db_id}", task_id
        )
        log_with_timestamp(
            "INFO",
            f"馃搵 [EXECUTE] asyncio event loop running: {asyncio.get_event_loop().is_running()}",
            task_id,
        )

        task: TranscriptionTask | None = None
        try:
            logger.info(
                f"馃敆 [EXECUTE] Using provided database session for task {task_id}"
            )

            # 鍒濆鍖?AI 妯″瀷閰嶇疆浠撳簱锛堢敤浜庤褰曠粺璁★級
            ai_repo = AIModelConfigRepository(session)
            # 鑾峰彇浠诲姟淇℃伅
            stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
            result = await session.execute(stmt)
            task = result.scalar_one_or_none()

            if not task:
                logger.error(
                    f"鉂?[EXECUTE] Transcription task {task_id} not found in database"
                )
                raise RuntimeError(f"Transcription task {task_id} not found")

            # 妫€鏌ヤ换鍔℃槸鍚﹀凡缁忓畬鎴愶紝閬垮厤閲嶅鎵ц
            if task.status == TranscriptionStatus.COMPLETED:
                log_with_timestamp(
                    "INFO",
                    f"鉁?[SKIP] Task {task_id} already completed, skipping execution",
                    task_id,
                )
                log_with_timestamp(
                    "INFO",
                    f"馃搫 [SKIP] Transcript has {task.transcript_word_count or 0} words",
                    task_id,
                )
                return

            # 妫€鏌ヤ换鍔℃槸鍚﹀凡鍙栨秷鎴栧け璐ヤ笖涓嶅簲閲嶈瘯
            if task.status == TranscriptionStatus.CANCELLED:
                log_with_timestamp(
                    "WARNING",
                    f"鈿狅笍 [SKIP] Task {task_id} was cancelled, skipping execution",
                    task_id,
                )
                return

            # 鑾峰彇鎾鍗曢泦淇℃伅 (棰勫姞杞絪ubscription鍏崇郴浠ラ伩鍏峫azy load)
            from sqlalchemy.orm import selectinload

            stmt = (
                select(PodcastEpisode)
                .options(selectinload(PodcastEpisode.subscription))
                .where(PodcastEpisode.id == task.episode_id)
            )
            result = await session.execute(stmt)
            episode = result.scalar_one_or_none()

            if not episode:
                logger.error(
                    f"transcription._execute_transcription: Episode {task.episode_id} not found for task {task_id}"
                )
                await self._set_task_final_status(
                    session, task_id, TranscriptionStatus.FAILED, "Episode not found"
                )
                raise RuntimeError(f"Episode {task.episode_id} not found")

            # 鑾峰彇杞綍閰嶇疆
            api_url = self.default_api_url
            api_key = self.default_api_key

            if config_db_id:
                logger.info(
                    f"transcription._execute_transcription: Using custom model config {config_db_id}"
                )
                model_config = await ai_repo.get_by_id(config_db_id)
                if model_config and model_config.is_active:
                    api_url = model_config.api_url
                    # 鑾峰彇API Key - 鏀寔鍔犲瘑瑙ｅ瘑
                    if (
                        model_config.is_system
                        and model_config.provider == "siliconflow"
                    ):
                        api_key = (
                            getattr(settings, "TRANSCRIPTION_API_KEY", None)
                            or model_config.api_key
                        )
                    elif model_config.is_system and model_config.provider == "openai":
                        api_key = (
                            getattr(settings, "OPENAI_API_KEY", None)
                            or model_config.api_key
                        )
                    else:
                        # 鐢ㄦ埛鑷畾涔夋ā鍨?- 闇€瑕佽В瀵?
                        if model_config.api_key_encrypted and model_config.api_key:
                            from app.core.security import decrypt_data

                            try:
                                api_key = decrypt_data(model_config.api_key)
                                logger.info(
                                    f"馃攽 [KEY] Decrypted API key for model {model_config.name} (first 10 chars): {api_key[:10]}..."
                                )
                            except Exception as e:
                                logger.error(f"Failed to decrypt API key: {e}")
                                api_key = model_config.api_key
                        else:
                            api_key = model_config.api_key

            if not api_key:
                logger.error(
                    f"transcription._execute_transcription: API Key missing for task {task_id}"
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Transcription API Key not found",
                )
                raise RuntimeError("Transcription API key not found")

            # 鍒涘缓涓存椂鐩綍
            temp_episode_dir = os.path.join(self.temp_dir, f"episode_{task.episode_id}")
            os.makedirs(temp_episode_dir, exist_ok=True)
            logger.info(
                f"transcription._execute_transcription: Created temp dir {temp_episode_dir}"
            )

            # === 姝ラ璺宠繃閫昏緫锛氭牴鎹?current_step 鍐冲畾浠庡摢涓€姝ュ紑濮?===
            start_step = task.current_step
            log_with_timestamp(
                "INFO",
                f"馃搷 [RESUME] Current step: {start_step}, will resume from this step",
                task_id,
            )

            # 姝ラ鎵ц椤哄簭锛欴OWNLOADING -> CONVERTING -> SPLITTING -> TRANSCRIBING -> MERGING
            # 濡傛灉 current_step 鍦ㄦ煇涓楠や箣鍚庯紝鍓嶉潰鐨勬楠ゅ皢琚烦杩?

            # === 姝ラ1锛氫笅杞介煶棰戞枃浠讹紙鏀寔澧為噺鎭㈠锛?===
            download_start = time.time()
            download_time = 0
            original_file = os.path.join(
                temp_episode_dir,
                f"original{os.path.splitext(task.original_audio_url)[-1]}",
            )
            file_size = 0

            # 妫€鏌ユ槸鍚﹀凡涓嬭浇
            if os.path.exists(original_file) and os.path.getsize(original_file) > 0:
                file_size = os.path.getsize(original_file)
                log_with_timestamp(
                    "INFO",
                    f"鈴笍 [STEP 1/6 DOWNLOAD] Skip! File already exists: {original_file} ({file_size / 1024 / 1024:.2f} MB)",
                    task_id,
                )
                log_with_timestamp(
                    "INFO",
                    "鉁?[STEP 1/6 DOWNLOAD] Using existing downloaded file",
                    task_id,
                )
            else:
                log_with_timestamp(
                    "INFO",
                    "馃摜 [STEP 1/6 DOWNLOAD] Starting audio download with fallback...",
                    task_id,
                )
                log_with_timestamp(
                    "INFO",
                    f"馃摜 [STEP 1/6 DOWNLOAD] Source URL: {task.original_audio_url[:100]}...",
                    task_id,
                )
                await self._update_task_progress_with_session(
                    session, task_id, "downloading", 5, "Downloading audio file..."
                )

                logger.info(f"馃摜 [STEP 1 DOWNLOAD] Target path: {original_file}")

                async with AudioDownloader() as downloader:
                    # 浣跨敤鑺傛祦鍣ㄥ噺灏戞棩蹇?
                    last_dl_progress = 0.0

                    async def download_progress(progress):
                        nonlocal last_dl_progress

                        # 姣?0%璁板綍涓€娆′笅杞芥棩蹇?
                        if int(progress) // 10 > int(last_dl_progress) // 10:
                            logger.info(
                                f"馃摜 [STEP 1 DOWNLOAD] Progress: {progress:.1f}%"
                            )
                            last_dl_progress = progress

                        await self._update_task_progress_with_session(
                            session,
                            task_id,
                            "downloading",
                            5 + (progress * 0.15),  # 5-20%
                            f"Downloading... {progress:.1f}%",
                        )

                    # 浣跨敤甯﹀洖閫€鏈哄埗鐨勪笅杞芥柟娉?
                    file_path, file_size = await downloader.download_file_with_fallback(
                        task.original_audio_url, original_file, download_progress
                    )

                log_with_timestamp(
                    "INFO",
                    f"鉁?[STEP 1/6 DOWNLOAD] Download complete! Size: {file_size} bytes ({file_size / 1024 / 1024:.2f} MB)",
                    task_id,
                )
                download_time = time.time() - download_start
                log_with_timestamp(
                    "INFO",
                    f"鈴憋笍 [STEP 1/6 DOWNLOAD] Time taken: {download_time:.2f}s",
                    task_id,
                )

            file_path = original_file  # 纭繚file_path鎸囧悜姝ｇ‘鐨勬枃浠?

            # === 姝ラ2锛氳浆鎹负MP3锛堟敮鎸佸閲忔仮澶嶏級 ===
            conversion_time = 0
            converted_file = os.path.join(temp_episode_dir, "converted.mp3")

            log_with_timestamp(
                "INFO",
                f"馃攳 [STEP 2/6 CONVERT] Checking conversion status: {converted_file}",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"馃攳 [STEP 2/6 CONVERT] File exists: {os.path.exists(converted_file)}",
                task_id,
            )

            # 妫€鏌ユ槸鍚﹀凡杞崲锛堟洿涓ユ牸鐨勯獙璇侊級
            skip_conversion = False
            if os.path.exists(converted_file):
                converted_size = os.path.getsize(converted_file)
                log_with_timestamp(
                    "INFO",
                    f"馃攳 [STEP 2/6 CONVERT] Found existing file: {converted_size} bytes",
                    task_id,
                )
                # 楠岃瘉鏂囦欢澶у皬鍚堢悊锛堣嚦灏?0KB锛屼笖涓嶈秴杩囧師濮嬫枃浠跺お澶氾級
                if converted_size > 10240:  # 鑷冲皯10KB
                    # 灏濊瘯鐢╢fmpeg楠岃瘉鏂囦欢鏄惁鏄湁鏁堢殑MP3
                    try:
                        import ffmpeg

                        probe = ffmpeg.probe(converted_file)
                        log_with_timestamp(
                            "INFO",
                            f"馃攳 [STEP 2/6 CONVERT] FFmpeg probe result: {probe}",
                            task_id,
                        )
                        duration = (
                            probe.get("format", {}).get("duration") if probe else None
                        )
                        if duration:
                            skip_conversion = True
                            log_with_timestamp(
                                "INFO",
                                f"鈴笍 [STEP 2/6 CONVERT] Skip! Valid MP3 file already exists: {converted_file} ({converted_size / 1024 / 1024:.2f} MB, {duration}s)",
                                task_id,
                            )
                            log_with_timestamp(
                                "INFO",
                                "鉁?[STEP 2/6 CONVERT] Using existing converted file",
                                task_id,
                            )
                        else:
                            log_with_timestamp(
                                "WARNING",
                                f"鈿狅笍 [STEP 2/6 CONVERT] File exists but invalid (no duration), re-converting: {converted_file}",
                                task_id,
                            )
                    except Exception as e:
                        log_with_timestamp(
                            "WARNING",
                            f"鈿狅笍 [STEP 2/6 CONVERT] File exists but validation failed ({str(e)}), re-converting",
                            task_id,
                        )
                    else:
                        log_with_timestamp(
                            "WARNING",
                            f"鈿狅笍 [STEP 2/6 CONVERT] File exists but too small ({converted_size} bytes), re-converting",
                            task_id,
                        )
                else:
                    log_with_timestamp(
                        "INFO",
                        "馃攳 [STEP 2/6 CONVERT] File does not exist, will convert",
                        task_id,
                    )

            if not skip_conversion:
                log_with_timestamp(
                    "INFO",
                    "馃攧 [STEP 2/6 CONVERT] Starting MP3 conversion...",
                    task_id,
                )
                await self._update_task_progress_with_session(
                    session, task_id, "converting", 20, "Converting to MP3..."
                )

                async def convert_progress(progress):
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "converting",
                        20 + (progress * 0.15),  # 20-35%
                        f"Converting... {progress:.1f}%",
                    )

                _, conversion_time = await AudioConverter.convert_to_mp3(
                    file_path, converted_file, convert_progress
                )

                # Verify the converted file was actually created
                if not os.path.exists(converted_file):
                    error_msg = f"Conversion completed but output file not found: {converted_file}"
                    logger.error(f"鉂?[STEP 2/6 CONVERT] {error_msg}")
                    logger.error(
                        f"鉂?[STEP 2/6 CONVERT] Input file: {file_path}, exists: {os.path.exists(file_path)}"
                    )
                    await self._set_task_final_status(
                        session,
                        task_id,
                        TranscriptionStatus.FAILED,
                        "MP3 conversion failed - output file not created",
                    )
                    raise RuntimeError(
                        "MP3 conversion failed - output file not created"
                    )

                converted_size = os.path.getsize(converted_file)
                log_with_timestamp(
                    "INFO",
                    f"鉁?[STEP 2/6 CONVERT] Conversion complete! Output: {converted_file} ({converted_size / 1024 / 1024:.2f} MB), Time: {conversion_time:.2f}s",
                    task_id,
                )

            # Final verification before moving to STEP 3
            log_with_timestamp(
                "INFO",
                f"馃攳 [STEP 2->3] Final check: converted_file exists = {os.path.exists(converted_file)}, size = {os.path.getsize(converted_file) if os.path.exists(converted_file) else 0}",
                task_id,
            )

            # === 姝ラ3锛氬垏鍓查煶棰戞枃浠讹紙鏀寔澧為噺鎭㈠锛?===
            # 棣栧厛楠岃瘉converted_file纭疄瀛樺湪涓旀湁鏁?
            log_with_timestamp(
                "INFO", "馃搵 [STEP 3/6 SPLIT] Starting split verification...", task_id
            )

            if not os.path.exists(converted_file):
                error_msg = f"Converted file not found: {converted_file}. Cannot proceed with split."
                logger.error(f"鉂?[STEP 3/6 SPLIT] {error_msg}")
                logger.error(f"鉂?[STEP 3/6 SPLIT] Working directory: {os.getcwd()}")
                logger.error(
                    f"鉂?[STEP 3/6 SPLIT] Temp dir exists: {os.path.exists(temp_episode_dir)}"
                )
                if os.path.exists(temp_episode_dir):
                    files = os.listdir(temp_episode_dir)
                    logger.error(f"鉂?[STEP 3/6 SPLIT] Files in temp dir: {files}")
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Converted audio file missing, cannot split",
                )
                raise RuntimeError("Converted audio file missing, cannot split")

            converted_file_size = os.path.getsize(converted_file)
            if converted_file_size == 0:
                error_msg = f"Converted file is empty: {converted_file}. Cannot proceed with split."
                logger.error(f"鉂?[STEP 3/6 SPLIT] {error_msg}")
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Converted audio file is empty, cannot split",
                )
                raise RuntimeError("Converted audio file is empty, cannot split")

            log_with_timestamp(
                "INFO",
                f"馃搵 [STEP 3/6 SPLIT] Verified converted file exists: {converted_file} ({converted_file_size / 1024 / 1024:.2f} MB)",
                task_id,
            )

            split_dir = os.path.join(temp_episode_dir, "chunks")

            # 妫€鏌ユ槸鍚﹀凡鍒嗗壊
            if os.path.exists(split_dir) and os.path.isdir(split_dir):
                # 妫€鏌ユ槸鍚︽湁chunk鏂囦欢
                chunk_file_pattern = re.compile(r".+_chunk_(\d+)\.mp3$")
                existing_chunks: list[tuple[int, str]] = []
                for file_name in os.listdir(split_dir):
                    match = chunk_file_pattern.fullmatch(file_name)
                    if match:
                        existing_chunks.append((int(match.group(1)), file_name))

                if existing_chunks:
                    log_with_timestamp(
                        "INFO",
                        f"鈴笍 [STEP 3/6 SPLIT] Skip! Chunks already exist: {len(existing_chunks)} files found",
                        task_id,
                    )
                    log_with_timestamp(
                        "INFO", "鉁?[STEP 3/6 SPLIT] Using existing chunks", task_id
                    )
                    # 閲嶅缓chunks瀵硅薄鍒楄〃
                    chunks = []
                    for index, chunk_file in sorted(
                        existing_chunks, key=lambda item: item[0]
                    ):
                        chunk_path = os.path.join(split_dir, chunk_file)
                        file_size = os.path.getsize(chunk_path)
                        chunks.append(
                            AudioChunk(
                                index=index,
                                file_path=chunk_path,
                                start_time=0,  # 杩欎簺淇℃伅浼氫粠鏂囦欢涓幏鍙?
                                duration=0,
                                file_size=file_size,
                                transcript=None,
                            )
                        )
                else:
                    # 闇€瑕佹墽琛屽垎鍓?
                    log_with_timestamp(
                        "INFO",
                        f"鉁傦笍 [STEP 3/6 SPLIT] Starting audio split with chunk_size_mb={task.chunk_size_mb}...",
                        task_id,
                    )
                    await self._update_task_progress_with_session(
                        session, task_id, "splitting", 35, "Splitting audio file..."
                    )

                    async def split_progress(progress):
                        await self._update_task_progress_with_session(
                            session,
                            task_id,
                            "splitting",
                            35 + (progress * 0.10),  # 35-45%
                            f"Splitting... {progress:.1f}%",
                        )

                    chunks = await AudioSplitter.split_mp3(
                        converted_file, split_dir, task.chunk_size_mb, split_progress
                    )
                    log_with_timestamp(
                        "INFO",
                        f"鉁?[STEP 3/6 SPLIT] Split complete! Created {len(chunks)} chunks",
                        task_id,
                    )
            else:
                # 闇€瑕佹墽琛屽垎鍓?
                log_with_timestamp(
                    "INFO",
                    f"鉁傦笍 [STEP 3/6 SPLIT] Starting audio split with chunk_size_mb={task.chunk_size_mb}...",
                    task_id,
                )
                await self._update_task_progress_with_session(
                    session, task_id, "splitting", 35, "Splitting audio file..."
                )

                async def split_progress(progress):
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "splitting",
                        35 + (progress * 0.10),  # 35-45%
                        f"Splitting... {progress:.1f}%",
                    )

                chunks = await AudioSplitter.split_mp3(
                    converted_file, split_dir, task.chunk_size_mb, split_progress
                )
                log_with_timestamp(
                    "INFO",
                    f"鉁?[STEP 3/6 SPLIT] Split complete! Created {len(chunks)} chunks",
                    task_id,
                )

            # === 姝ラ4锛氳浆褰曢煶棰戠墖娈碉紙鏀寔澧為噺鎭㈠锛?===
            # 妫€鏌ユ槸鍚︽湁宸茶浆褰曠殑鐗囨
            chunks_to_transcribe = []
            already_transcribed = []
            for chunk in chunks:
                transcript_file = chunk.file_path.replace(".mp3", ".txt")
                if (
                    os.path.exists(transcript_file)
                    and os.path.getsize(transcript_file) > 0
                ):
                    # 鍔犺浇宸叉湁鐨勮浆褰?
                    async with aiofiles.open(transcript_file, encoding="utf-8") as f:
                        content = await f.read()
                    if content.strip():
                        chunk.transcript = content
                        already_transcribed.append(chunk)
                else:
                    chunks_to_transcribe.append(chunk)

            if already_transcribed:
                log_with_timestamp(
                    "INFO",
                    f"鈴笍 [STEP 4/6 TRANSCRIBE] Found {len(already_transcribed)} already transcribed chunks, skipping",
                    task_id,
                )

            log_with_timestamp(
                "INFO",
                f"馃 [STEP 4/6 TRANSCRIBE] Starting transcription of {len(chunks_to_transcribe)} remaining chunks...",
                task_id,
            )
            log_with_timestamp(
                "INFO", f"馃 [STEP 4/6 TRANSCRIBE] Model: {task.model_used}", task_id
            )

            if chunks_to_transcribe:
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "transcribing",
                    45,
                    f"Transcribing {len(chunks_to_transcribe)} audio chunks...",
                )

                transcription_start = time.time()

                # 浣跨敤鑺傛祦鍣ㄥ噺灏戞棩蹇?
                last_trans_progress = 0.0

                async def transcribe_progress(progress):
                    nonlocal last_trans_progress

                    # 姣?0%璁板綍涓€娆¤浆褰曟棩蹇?
                    if int(progress) // 10 > int(last_trans_progress) // 10:
                        logger.info(
                            f"馃 [STEP 4 TRANSCRIBE] Progress: {progress:.1f}%"
                        )
                        last_trans_progress = progress

                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "transcribing",
                        45 + (progress * 0.50),  # 45-95%
                        f"Transcribing... {progress:.1f}%",
                    )

                async with SiliconFlowTranscriber(
                    api_key, api_url, self.max_threads
                ) as transcriber:
                    transcribed_chunks = await transcriber.transcribe_chunks(
                        chunks_to_transcribe,
                        task.model_used,
                        transcribe_progress,
                        ai_repo=ai_repo,
                        config_db_id=config_db_id,
                    )

                # 鍚堝苟宸叉湁杞綍鍜屾柊杞綍
                all_chunks = already_transcribed + transcribed_chunks

                log_with_timestamp(
                    "INFO",
                    "鉁?[STEP 4/6 TRANSCRIBE] Transcription chunks finished!",
                    task_id,
                )

                # Log transcription results summary
                success_count = sum(1 for c in all_chunks if c.transcript)
                failed_count = len(all_chunks) - success_count
                log_with_timestamp(
                    "INFO",
                    f"馃搳 [STEP 4/6 TRANSCRIBE] Results: {success_count} succeeded, {failed_count} failed out of {len(all_chunks)} total",
                    task_id,
                )

                transcription_time = time.time() - transcription_start
                log_with_timestamp(
                    "INFO",
                    f"鈴憋笍 [STEP 4/6 TRANSCRIBE] Time taken: {transcription_time:.2f}s",
                    task_id,
                )
            else:
                # 鎵€鏈夌墖娈甸兘宸茶浆褰?
                all_chunks = already_transcribed
                log_with_timestamp(
                    "INFO",
                    "鉁?[STEP 4/6 TRANSCRIBE] All chunks already transcribed! Skipping transcription",
                    task_id,
                )
                success_count = len(all_chunks)
                failed_count = 0
                transcription_time = 0

            total_chunks = len(all_chunks)
            success_ratio = (success_count / total_chunks) if total_chunks else 0.0
            if success_count == 0 or success_ratio < self.min_chunk_success_ratio:
                threshold = self.min_chunk_success_ratio
                error_message = (
                    "Insufficient successful chunks for transcript merge: "
                    f"success={success_count}, failed={failed_count}, "
                    f"total={total_chunks}, ratio={success_ratio:.2f}, "
                    f"required_ratio={threshold:.2f}"
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    error_message,
                )
                raise RuntimeError(error_message)

            # 姝ラ5锛氬悎骞惰浆褰曠粨鏋?
            log_with_timestamp(
                "INFO",
                "馃敆 [STEP 5/6 MERGE] Merging transcription results...",
                task_id,
            )
            await self._update_task_progress_with_session(
                session, task_id, "merging", 95, "Merging transcription results..."
            )

            # 鎸夐『搴忓悎骞惰浆褰曟枃鏈?
            sorted_chunks = sorted(all_chunks, key=lambda x: x.index)
            full_transcript = "\n\n".join(
                [
                    chunk.transcript.strip()
                    for chunk in sorted_chunks
                    if chunk.transcript and chunk.transcript.strip()
                ]
            )

            log_with_timestamp(
                "INFO",
                f"馃搫 [STEP 5/6 MERGE] Merged transcript: {len(full_transcript)} chars, {len(full_transcript.split())} words",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"馃搫 [STEP 5/6 MERGE] Preview: {full_transcript[:150]}...",
                task_id,
            )

            # 姝ラ6锛氫繚瀛樼粨鏋滃埌姘镐箙瀛樺偍
            storage_path = self._get_episode_storage_path(episode)
            os.makedirs(storage_path, exist_ok=True)

            # 淇濆瓨鍘熷闊抽鏂囦欢
            final_audio_path = os.path.join(storage_path, "original.mp3")

            # Verify converted file exists before copying
            if not os.path.exists(converted_file):
                error_msg = f"Converted audio file not found: {converted_file}"
                logger.error(f"鉂?[STEP 6 SAVE] {error_msg}")
                logger.error(f"鉂?[STEP 6 SAVE] Working directory: {os.getcwd()}")
                logger.error(
                    f"鉂?[STEP 6 SAVE] Absolute path: {os.path.abspath(converted_file)}"
                )
                # List files in temp directory for debugging
                if os.path.exists(temp_episode_dir):
                    files = os.listdir(temp_episode_dir)
                    logger.error(f"鉂?[STEP 6 SAVE] Files in temp dir: {files}")
                else:
                    logger.error(
                        f"鉂?[STEP 6 SAVE] Temp directory does not exist: {temp_episode_dir}"
                    )
                raise FileNotFoundError(error_msg)

            # Move audio file to permanent storage
            # Use shutil.move instead of os.replace to handle cross-device moves (e.g., Docker volumes)
            # 浣跨敤 shutil.move 鑰岄潪 os.replace锛屼互澶勭悊璺ㄨ澶囩Щ鍔紙濡?Docker 鍗凤級
            import shutil

            try:
                shutil.move(converted_file, final_audio_path)
            except OSError as e:
                logger.warning(
                    f"鈿狅笍 [STEP 6 SAVE] shutil.move failed ({e}), trying copy + delete"
                )
                shutil.copy2(converted_file, final_audio_path)
                try:
                    os.remove(converted_file)
                except OSError:
                    logger.warning(
                        f"鈿狅笍 [STEP 6 SAVE] Could not remove source file: {converted_file}"
                    )

            # 淇濆瓨杞綍鏂囨湰
            transcript_path = os.path.join(storage_path, "transcript.txt")
            async with aiofiles.open(transcript_path, "w", encoding="utf-8") as f:
                await f.write(full_transcript)

            log_with_timestamp(
                "INFO",
                f"馃捑 [STEP 6/6 SAVE] Transcript saved to: {transcript_path}",
                task_id,
            )

            # 鏇存柊浠诲姟璇︾粏淇℃伅
            task_update = {
                "status": TranscriptionStatus.COMPLETED,
                "current_step": "merging",  # 淇濇寔鏈€鍚庣殑姝ラ
                "progress_percentage": 100.0,
                "transcript_content": full_transcript,
                "transcript_word_count": len(full_transcript.split()),
                "original_file_path": final_audio_path,
                "original_file_size": file_size,
                "download_time": download_time,
                "conversion_time": conversion_time,
                "transcription_time": transcription_time,
                "chunk_info": {
                    "total_chunks": len(chunks),
                    "chunks": [
                        {
                            "index": chunk.index,
                            "start_time": chunk.start_time,
                            "duration": chunk.duration,
                            "transcript": chunk.transcript,
                        }
                        for chunk in sorted_chunks
                    ],
                },
                "completed_at": datetime.now(timezone.utc),
            }

            stmt = (
                update(TranscriptionTask)
                .where(TranscriptionTask.id == task_id)
                .values(**task_update)
            )
            await session.execute(stmt)

            # 鏇存柊鎾鍗曢泦鐨勮浆褰曚俊鎭?
            episode_update = {
                "transcript_content": full_transcript,
                "transcript_url": f"file://{transcript_path}",
                "status": "pending_summary",
            }

            stmt = (
                update(PodcastEpisode)
                .where(PodcastEpisode.id == task.episode_id)
                .values(**episode_update)
            )
            await session.execute(stmt)

            await session.commit()

            total_time = time.time() - download_start
            log_with_timestamp(
                "INFO",
                f"鉁?[TRANSCRIPTION COMPLETE] Successfully completed transcription for episode {task.episode_id}",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"鉁?[TRANSCRIPTION COMPLETE] Total time: {total_time:.2f}s (download:{download_time:.2f}s, convert:{conversion_time:.2f}s, transcribe:{transcription_time:.2f}s)",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"鉁?[TRANSCRIPTION COMPLETE] Transcript: {len(full_transcript)} chars, {len(full_transcript.split())} words",
                task_id,
            )

            # 瑙﹀彂AI鎬荤粨
            log_with_timestamp(
                "INFO",
                f"馃 [AI SUMMARY] Scheduling AI summary for episode {task.episode_id}",
                task_id,
            )
            await self._schedule_ai_summary(session, task_id)
        except Exception as e:
            import traceback

            error_trace = traceback.format_exc()
            logger.error(
                f"鉂?[EXECUTE ERROR] Transcription failed for task {task_id}: {str(e)}"
            )
            logger.error(f"鉂?[EXECUTE ERROR] Traceback:\n{error_trace}")
            status_stmt = select(TranscriptionTask.status).where(
                TranscriptionTask.id == task_id
            )
            status_result = await session.execute(status_stmt)
            current_status = status_result.scalar()
            if current_status not in {
                TranscriptionStatus.COMPLETED,
                TranscriptionStatus.FAILED,
                TranscriptionStatus.CANCELLED,
                "completed",
                "failed",
                "cancelled",
            }:
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    f"Transcription failed: {str(e)}",
                )
            raise
        finally:
            # Only clean up temporary files if the task completed successfully
            # Failed or interrupted tasks should keep their temp files for incremental recovery
            try:
                # Re-fetch task status to see if it completed successfully
                stmt_check = select(TranscriptionTask.status).where(
                    TranscriptionTask.id == task_id
                )
                result_check = await session.execute(stmt_check)
                final_status = result_check.scalar()

                if final_status == TranscriptionStatus.COMPLETED and task is not None:
                    import shutil

                    temp_episode_dir = os.path.join(
                        self.temp_dir, f"episode_{task.episode_id}"
                    )
                    if os.path.exists(temp_episode_dir):
                        shutil.rmtree(temp_episode_dir)
                        logger.info(
                            f"馃Ч [CLEANUP] Cleaned up temporary directory for successful task {task_id}: {temp_episode_dir}"
                        )
                elif task is not None:
                    temp_episode_dir = os.path.join(
                        self.temp_dir, f"episode_{task.episode_id}"
                    )
                    if os.path.exists(temp_episode_dir):
                        logger.info(
                            f"鈴革笍 [CLEANUP] Preserving temporary directory for task {task_id} (status={final_status}): {temp_episode_dir}"
                        )
            except Exception as e:
                logger.error(f"鈿狅笍 [CLEANUP] Error during cleanup: {str(e)}")

    async def get_transcription_status(self, task_id: int) -> TranscriptionTask | None:
        """鑾峰彇杞綍浠诲姟鐘舵€?"""
        stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_episode_transcription(
        self, episode_id: int
    ) -> TranscriptionTask | None:
        """鑾峰彇鎾鍗曢泦鐨勮浆褰曚俊鎭?"""
        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def _schedule_ai_summary(self, session: AsyncSession, task_id: int):
        """璋冨害AI鎬荤粨浠诲姟"""
        task: TranscriptionTask | None = None
        try:
            # 鑾峰彇杞綍浠诲姟
            log_with_timestamp(
                "INFO",
                f"馃攳 [AI SUMMARY] Getting transcription task {task_id}",
                task_id,
            )
            stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
            result = await session.execute(stmt)
            task = result.scalar_one_or_none()

            if not task:
                log_with_timestamp(
                    "ERROR",
                    f"鉂?[AI SUMMARY] Transcription task {task_id} not found",
                    task_id,
                )
                return

            log_with_timestamp(
                "INFO",
                f"鉁?[AI SUMMARY] Found transcription task {task_id} for episode {task.episode_id}",
                task_id,
            )

            # 浣跨敤DatabaseBackedAISummaryService鐢熸垚鎬荤粨
            summary_service = DatabaseBackedAISummaryService(session)
            log_with_timestamp(
                "INFO",
                f"馃 [AI SUMMARY] Starting AI summary generation for episode {task.episode_id}",
                task_id,
            )

            # 璋冪敤AI鎬荤粨鏈嶅姟
            summary_result = await summary_service.generate_summary(task.episode_id)

            # 璁＄畻瀛楁暟
            word_count = len(summary_result["summary_content"].split())

            log_with_timestamp(
                "INFO",
                f"鉁?[AI SUMMARY] Successfully generated summary for episode {task.episode_id}",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"鉁?[AI SUMMARY] Summary: {len(summary_result['summary_content'])} chars, {word_count} words",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"鉁?[AI SUMMARY] Processing time: {summary_result['processing_time']:.2f}s, Model: {summary_result['model_name']}",
                task_id,
            )

            # 馃敟 鍏抽敭淇: 鍒锋柊session涓殑task瀵硅薄锛岀‘淇滱I鎽樿绔嬪嵆鍙
            # 杩欐槸鍥犱负 summary_service.generate_summary() 鍐呴儴浣跨敤浜嗙嫭绔嬬殑db session鎻愪氦
            # 鎴戜滑闇€瑕佸埛鏂板綋鍓峴ession涓殑task瀵硅薄
            try:
                await session.refresh(task)
                log_with_timestamp(
                    "INFO",
                    "馃攧 [AI SUMMARY] Refreshed task object from database, summary_content is now available",
                    task_id,
                )
            except Exception as refresh_error:
                log_with_timestamp(
                    "WARNING",
                    f"鈿狅笍 [AI SUMMARY] Failed to refresh task: {refresh_error}",
                    task_id,
                )

        except Exception as e:
            import traceback

            error_trace = traceback.format_exc()
            error_msg = str(e)
            log_with_timestamp(
                "ERROR",
                f"鉂?[AI SUMMARY] Failed to generate summary for task {task_id}: {error_msg}",
                task_id,
            )
            logger.error(f"鉂?[AI SUMMARY] Traceback: {error_trace}")

            if task is None:
                return

            episode_meta_stmt = select(PodcastEpisode.metadata_json).where(
                PodcastEpisode.id == task.episode_id
            )
            episode_meta_result = await session.execute(episode_meta_stmt)
            metadata_json = episode_meta_result.scalar_one_or_none() or {}
            metadata_json["summary_error"] = error_msg
            metadata_json["summary_failed_at"] = datetime.now(timezone.utc).isoformat()

            await session.execute(
                update(PodcastEpisode)
                .where(PodcastEpisode.id == task.episode_id)
                .values(
                    status="summary_failed",
                    metadata_json=metadata_json,
                    updated_at=datetime.now(timezone.utc),
                )
            )
            await session.execute(
                update(TranscriptionTask)
                .where(TranscriptionTask.id == task_id)
                .values(
                    summary_error_message=error_msg,
                    updated_at=datetime.now(timezone.utc),
                )
            )
            await session.commit()

    async def cancel_transcription(self, task_id: int) -> bool:
        """鍙栨秷杞綍浠诲姟"""
        task = await self.get_transcription_status(task_id)
        if not task:
            return False

        if task.status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            return False

        await self.update_task_progress(
            task_id,
            TranscriptionStatus.CANCELLED,
            task.progress_percentage,
            "Transcription cancelled by user",
        )

        return True
