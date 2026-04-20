"""Audio file downloader with retry-friendly request metadata."""

import logging
import os

import aiofiles
import aiohttp
from fastapi import HTTPException, status


logger = logging.getLogger(__name__)


class AudioDownloader:
    """Download audio files with retry-friendly request metadata."""

    def __init__(self, timeout: int = 300, chunk_size: int = 8192):
        self.timeout = timeout
        self.chunk_size = chunk_size
        self.session: aiohttp.ClientSession | None = None

    async def __aenter__(self):
        """Create and return an aiohttp session."""
        connector = aiohttp.TCPConnector(limit=10, limit_per_host=5)
        timeout = aiohttp.ClientTimeout(total=self.timeout)
        # Use browser-like headers to reduce CDN rejection risk.
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
            connector=connector,
            timeout=timeout,
            headers=headers,
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Close the aiohttp session."""
        if self.session:
            await self.session.close()

    async def download_file(
        self,
        url: str,
        destination: str,
        progress_callback=None,
    ) -> tuple[str, int]:
        """Download a file to the destination path.

        Args:
            url: Source URL.
            destination: Destination file path.
            progress_callback: Optional async callback receiving progress percent.

        Returns:
            Tuple[str, int]: (saved file path, file size in bytes).

        """
        if not self.session:
            raise RuntimeError("AudioDownloader must be used as async context manager")

        # Ensure destination folder exists.
        os.makedirs(os.path.dirname(destination), exist_ok=True)

        # Replace lizhi.fm CDN host when required.
        original_url = url
        if "cdn.lizhi.fm" in url:
            url = url.replace("cdn.lizhi.fm", "cdn.gzlzfm.com")
            logger.info(
                f"[CDN REPLACEMENT] Replaced CDN URL: {original_url[:80]}... -> {url[:80]}...",
            )

        # Build request headers.
        request_headers = dict(self.session.headers)
        # Add Referer for lizhi.fm domains.
        if "lizhi.fm" in original_url or "lizhi.fm" in url or "gzlzfm.com" in url:
            request_headers["Referer"] = "https://www.lizhi.fm/"
            logger.info(
                "[HEADERS] Added Referer for lizhi.fm: https://www.lizhi.fm/",
            )

        # Emit request diagnostics.
        logger.info(f"[HTTP REQUEST] URL: {url}")
        logger.info(f"[HTTP REQUEST] Headers: {request_headers}")

        try:
            async with self.session.get(url, headers=request_headers) as response:
                # Emit response headers for debugging.
                logger.info(f"[Response Headers] {dict(response.headers)}")

                if response.status != 200:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"Failed to download audio file: HTTP {response.status}",
                    )

                # Read reported file size when available.
                content_length = response.headers.get("content-length")
                total_size = int(content_length) if content_length else 0

                # Stream file content in chunks.
                downloaded = 0
                first_chunk_logged = False
                async with aiofiles.open(destination, "wb") as f:
                    async for chunk in response.content.iter_chunked(self.chunk_size):
                        # Log a preview for the first chunk.
                        if not first_chunk_logged:
                            preview = chunk[:200]
                            logger.info(
                                f"[Response Body Preview] First 200 bytes: {preview}",
                            )
                            first_chunk_logged = True

                        await f.write(chunk)
                        downloaded += len(chunk)

                        # Report progress when total size is known.
                        if progress_callback and total_size > 0:
                            progress = (downloaded / total_size) * 100
                            await progress_callback(progress)

                logger.info(
                    f"Successfully downloaded file to {destination}, size: {downloaded} bytes",
                )
                return destination, downloaded

        except TimeoutError as err:
            raise HTTPException(
                status_code=status.HTTP_408_REQUEST_TIMEOUT,
                detail="Download timeout",
            ) from err
        except Exception as e:
            logger.error(f"Download failed: {e!s}")
            # Remove partially downloaded file.
            if os.path.exists(destination):
                os.remove(destination)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Download failed: {e!s}",
            ) from e

    async def download_file_with_fallback(
        self,
        url: str,
        destination: str,
        progress_callback=None,
    ) -> tuple[str, int]:
        """Download a file using aiohttp only.

        Args:
            url: Source URL.
            destination: Destination file path.
            progress_callback: Optional async callback receiving progress percent.

        Returns:
            Tuple[str, int]: (saved file path, file size in bytes).

        Raises:
            HTTPException: Raised when the download fails.

        """
        # Download directly with aiohttp.
        logger.info(f"[DOWNLOAD] Starting download for: {url[:100]}...")
        try:
            file_path, file_size = await self.download_file(
                url,
                destination,
                progress_callback,
            )
            logger.info(f"[DOWNLOAD] Download succeeded: {file_size} bytes")
            return file_path, file_size

        except Exception as e:
            logger.error(f"[DOWNLOAD] Download failed: {type(e).__name__}: {e!s}")
            if isinstance(e, HTTPException):
                raise
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Download failed: {e!s}",
            ) from e


# Note: Browser fallback download has been removed.
# The download now uses only aiohttp with proper headers and retry logic.
