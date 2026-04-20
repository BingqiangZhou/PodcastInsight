"""Audio format converter."""

import asyncio
import logging
import os
import time

import ffmpeg
from fastapi import HTTPException, status


logger = logging.getLogger(__name__)


class AudioConverter:
    """Convert audio files to MP3."""

    @staticmethod
    async def convert_to_mp3(
        input_path: str,
        output_path: str,
        progress_callback=None,
    ) -> tuple[str, float]:
        """MP3

        Args:
            input_path:
            output_path: MP3
            progress_callback:

        Returns:
            Tuple[str, float]: (, )

        """
        start_time = time.time()

        try:
            if not os.path.exists(input_path):
                raise FileNotFoundError(f"Input file not found: {input_path}")

            input_size = os.path.getsize(input_path)
            logger.info(
                f"[CONVERT] Starting conversion: {input_path} ({input_size / 1024 / 1024:.2f} MB) -> {output_path}",
            )

            os.makedirs(os.path.dirname(output_path), exist_ok=True)

            # FFmpeg
            ffmpeg_proc = (
                ffmpeg.input(input_path)
                .output(
                    output_path,
                    acodec="mp3",
                    ac=1,  # ?
                    ar="16000",  # 16kHz?
                    ab="64k",  # 64kbps?
                    f="mp3",
                )
                .overwrite_output()
                .global_args(
                    "-loglevel",
                    "error",
                )  # Changed from 'quiet' to 'error' for debugging
            )

            if progress_callback:
                await progress_callback(0)

            # Fmpeg
            cmd = ffmpeg_proc.compile()
            logger.debug(f"[CONVERT] FFmpeg command: {' '.join(cmd)}")

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )

            stdout, stderr = await process.communicate()

            if process.returncode != 0:
                error_msg = (
                    stderr.decode("utf-8", errors="replace")
                    if stderr
                    else "Unknown FFmpeg error"
                )
                logger.error(
                    f"[CONVERT] FFmpeg failed with return code {process.returncode}",
                )
                logger.error(f"[CONVERT] FFmpeg stderr: {error_msg}")
                raise RuntimeError(
                    f"FFmpeg conversion failed (code {process.returncode}): {error_msg}",
                )

            # Verify output file was created
            if not os.path.exists(output_path):
                raise RuntimeError(
                    f"FFmpeg completed successfully but output file not found: {output_path}",
                )

            output_size = os.path.getsize(output_path)
            if output_size == 0:
                os.remove(output_path)
                raise RuntimeError(f"FFmpeg created empty output file: {output_path}")

            if progress_callback:
                await progress_callback(100)

            duration = time.time() - start_time
            logger.info(
                f"[CONVERT] Successfully converted {input_path} to {output_path}",
            )
            logger.info(
                f"[CONVERT] Input: {input_size / 1024 / 1024:.2f} MB -> Output: {output_size / 1024 / 1024:.2f} MB, Time: {duration:.2f}s",
            )

            return output_path, duration

        except Exception as e:
            logger.error(
                f"[CONVERT] Audio conversion failed: {type(e).__name__}: {e!s}",
            )
            logger.error(
                f"[CONVERT] Input: {input_path} (exists: {os.path.exists(input_path)}), Output: {output_path} (exists: {os.path.exists(output_path)})",
            )
            if os.path.exists(output_path):
                try:
                    os.remove(output_path)
                    logger.debug(
                        f"[CONVERT] Removed partial output file: {output_path}",
                    )
                except Exception as cleanup_error:
                    logger.warning(
                        f"[CONVERT] Failed to remove partial output: {cleanup_error}",
                    )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Audio conversion failed: {e!s}",
            ) from e
