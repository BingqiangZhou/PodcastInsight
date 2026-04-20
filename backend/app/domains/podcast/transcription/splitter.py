"""Audio file splitter."""

import asyncio
import logging
import os

import ffmpeg
from fastapi import HTTPException, status

from .models import AudioChunk
from .utils import _ffmpeg_probe_async, _run_ffmpeg_sync


logger = logging.getLogger(__name__)


class AudioSplitter:
    """?"""

    @staticmethod
    async def split_mp3_by_duration(
        input_path: str,
        output_dir: str,
        chunk_duration_seconds: int = 300,
        progress_callback=None,
    ) -> list[AudioChunk]:
        """P3

        Args:
            input_path: MP3
            output_dir:
            chunk_duration_seconds: ?005?
            progress_callback:

        Returns:
            List[AudioChunk]:

        """
        try:
            os.makedirs(output_dir, exist_ok=True)

            # FFmpeg
            probe = await _ffmpeg_probe_async(input_path)
            duration = float(probe["streams"][0]["duration"])

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
                end_time = min(start_time + chunk_duration_seconds, duration)
                segment_duration = end_time - start_time

                output_path = os.path.join(
                    output_dir,
                    f"{base_name}_chunk_{i + 1:03d}.mp3",
                )

                # FFmpeg -
                await _run_ffmpeg_sync(
                    lambda start_time=start_time, segment_duration=segment_duration, output_path=output_path: (
                        ffmpeg.input(input_path, ss=start_time, t=segment_duration)
                        .output(
                            output_path,
                            acodec="mp3",
                            ac=1,  # ?
                            ar="16000",  # 16kHz?
                            ab="64k",  # 64kbps?
                        )
                        .overwrite_output()
                        .global_args("-loglevel", "quiet")
                        .run()
                    ),
                )

                chunk_file_size = os.path.getsize(output_path)

                chunk = AudioChunk(
                    index=i + 1,
                    file_path=output_path,
                    start_time=start_time,
                    duration=segment_duration,
                    file_size=chunk_file_size,
                )
                chunks.append(chunk)

                if progress_callback:
                    progress = ((i + 1) / num_chunks) * 100
                    await progress_callback(progress)

            logger.info(
                f"Successfully split {input_path} into {len(chunks)} chunks by time ({chunk_duration_seconds}s each)",
            )
            return chunks

        except Exception as e:
            logger.error(f"Audio splitting by time failed: {e!s}")
            for chunk in locals().get("chunks", []):
                if os.path.exists(chunk.file_path):
                    os.remove(chunk.file_path)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Audio splitting by time failed: {e!s}",
            ) from e

    @staticmethod
    async def split_mp3(
        input_path: str,
        output_dir: str,
        chunk_size_mb: int = 10,
        progress_callback=None,
    ) -> list[AudioChunk]:
        """P3

        Args:
            input_path: MP3
            output_dir:
            chunk_size_mb: MB?
            progress_callback:

        Returns:
            List[AudioChunk]:

        """
        try:
            if not os.path.exists(input_path):
                raise FileNotFoundError(f"Input file not found: {input_path}")

            input_size = os.path.getsize(input_path)
            logger.info(
                f"[SPLIT] Starting split: {input_path} ({input_size / 1024 / 1024:.2f} MB) into {chunk_size_mb}MB chunks",
            )

            os.makedirs(output_dir, exist_ok=True)
            logger.info(f"[SPLIT] Output directory: {output_dir}")

            file_size = os.path.getsize(input_path)
            chunk_size_bytes = chunk_size_mb * 1024 * 1024

            # FFmpeg
            try:
                probe = await _ffmpeg_probe_async(input_path)
                duration = float(probe["streams"][0]["duration"])
                logger.info(f"[SPLIT] Input duration: {duration:.2f}s")
            except Exception as e:
                logger.error(f"[SPLIT] FFmpeg probe failed: {e}")
                raise RuntimeError(f"Failed to probe input file: {e}") from e

            num_chunks = max(1, (file_size + chunk_size_bytes - 1) // chunk_size_bytes)
            chunk_duration = duration / num_chunks

            logger.info(
                f"[SPLIT] Will create {num_chunks} chunks, ~{chunk_duration:.2f}s each",
            )

            chunks = []
            base_name = os.path.splitext(os.path.basename(input_path))[0]

            for i in range(num_chunks):
                start_time = i * chunk_duration
                output_path = os.path.join(
                    output_dir,
                    f"{base_name}_chunk_{i + 1:03d}.mp3",
                )

                logger.debug(
                    f"[SPLIT] Creating chunk {i + 1}/{num_chunks}: {output_path} (start: {start_time:.2f}s, duration: {chunk_duration:.2f}s)",
                )

                # FFmpeg -
                try:
                    # FFmpeg
                    ffmpeg_cmd = (
                        ffmpeg.input(input_path, ss=start_time, t=chunk_duration)
                        .output(output_path, c="copy")
                        .overwrite_output()
                        .global_args(
                            "-loglevel",
                            "error",
                        )  # Changed from 'quiet' to 'error'
                        .compile()
                    )

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
                            f"FFmpeg split failed (code {process.returncode}): {error_msg}",
                        )

                except Exception as e:
                    logger.error(f"[SPLIT] Failed to create chunk {i + 1}: {e}")
                    raise

                # ?
                if not os.path.exists(output_path):
                    raise RuntimeError(
                        f"FFmpeg completed but output file not created: {output_path}",
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
                    f"[SPLIT] Created chunk {i + 1}: {chunk_file_size / 1024:.2f} KB",
                )

                if progress_callback:
                    progress = ((i + 1) / num_chunks) * 100
                    await progress_callback(progress)

            total_output_size = sum(c.file_size for c in chunks)
            logger.info(
                f"[SPLIT] Successfully split {input_path} into {len(chunks)} chunks ({total_output_size / 1024 / 1024:.2f} MB total)",
            )
            return chunks

        except Exception as e:
            logger.error(
                f"[SPLIT] Audio splitting failed: {type(e).__name__}: {e!s}",
            )
            logger.error(
                f"[SPLIT] Input: {input_path} (exists: {os.path.exists(input_path)}), Output dir: {output_dir}",
            )
            for chunk in locals().get("chunks", []):
                if os.path.exists(chunk.file_path):
                    try:
                        os.remove(chunk.file_path)
                        logger.debug(
                            f"[SPLIT] Removed partial chunk: {chunk.file_path}",
                        )
                    except Exception as cleanup_error:
                        logger.warning(
                            f"[SPLIT] Failed to remove partial chunk: {cleanup_error}",
                        )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Audio splitting failed: {e!s}",
            ) from e
