from __future__ import annotations

import asyncio
import os
from tempfile import TemporaryDirectory

import pytest

from app.domains.media.transcription import (
    AudioChunk,
    SiliconFlowTranscriber,
    build_chunk_info,
)


@pytest.mark.asyncio
async def test_transcribe_chunks_limits_in_flight_work() -> None:
    transcriber = SiliconFlowTranscriber(
        "test-key", "https://example.com", max_concurrent=2
    )
    active = 0
    peak_active = 0

    async def _fake_transcribe_chunk(chunk: AudioChunk, model: str) -> AudioChunk:
        del model
        nonlocal active, peak_active
        active += 1
        peak_active = max(peak_active, active)
        await asyncio.sleep(0.01)
        chunk.transcript = f"chunk-{chunk.index}"
        active -= 1
        return chunk

    transcriber.transcribe_chunk = _fake_transcribe_chunk
    chunks = [
        AudioChunk(
            index=index,
            file_path=f"chunk-{index}.mp3",
            start_time=float(index),
            duration=5.0,
            file_size=1024,
        )
        for index in range(1, 6)
    ]

    results = await transcriber.transcribe_chunks(chunks)

    assert peak_active <= 2
    assert [chunk.index for chunk in results] == [1, 2, 3, 4, 5]
    assert [chunk.transcript for chunk in results] == [
        "chunk-1",
        "chunk-2",
        "chunk-3",
        "chunk-4",
        "chunk-5",
    ]


def test_build_chunk_info_excludes_transcript_text() -> None:
    with TemporaryDirectory() as temp_dir:
        chunk_path = os.path.join(temp_dir, "chunk.mp3")
        with open(chunk_path, "wb") as file_obj:
            file_obj.write(b"fake audio bytes")

        chunk_info = build_chunk_info(
            [
                AudioChunk(
                    index=2,
                    file_path=chunk_path,
                    start_time=30.0,
                    duration=15.0,
                    file_size=512,
                    transcript=None,
                ),
                AudioChunk(
                    index=1,
                    file_path=chunk_path,
                    start_time=0.0,
                    duration=30.0,
                    file_size=1024,
                    transcript="hello world",
                ),
            ]
        )

    assert chunk_info == {
        "total_chunks": 2,
        "chunks": [
            {
                "index": 1,
                "start_time": 0.0,
                "duration": 30.0,
                "status": "completed",
            },
            {
                "index": 2,
                "start_time": 30.0,
                "duration": 15.0,
                "status": "failed",
            },
        ],
    }
