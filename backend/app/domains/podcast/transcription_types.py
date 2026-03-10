"""Shared transcription enums and lightweight contracts."""

from enum import StrEnum


class ScheduleFrequency(StrEnum):
    """Task scheduling frequency."""

    HOURLY = "hourly"
    DAILY = "daily"
    WEEKLY = "weekly"
    MANUAL = "manual"
