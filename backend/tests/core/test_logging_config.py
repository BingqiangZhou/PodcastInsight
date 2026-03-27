"""Comprehensive tests for the logging configuration module.

Covers:
- TimezoneFormatter: timezone-aware timestamp formatting, UTC handling,
  timezone offset parsing, fallback to default timezone
- setup_logging: root logger level, handler creation, log directory creation,
  console handler, file handlers, error file handler
- Log rotation: TimedRotatingFileHandler with correct when/backupCount/suffix
- Log levels: respects DEBUG, INFO, WARNING, ERROR levels
- Third-party noise suppression: reduces verbosity of uvicorn, sqlalchemy, etc.
- get_logger / create_logger: return named loggers
- get_log_files: file listing with glob patterns
"""

from __future__ import annotations

import logging
import logging.handlers
import os
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import patch

import pytest

from app.core.logging_config import (
    DEFAULT_LOG_DIR,
    DEFAULT_LOG_LEVEL,
    DEFAULT_RETENTION_DAYS,
    DEFAULT_TIMEZONE,
    SHANGHAI_OFFSET,
    TimezoneFormatter,
    create_logger,
    get_log_files,
    get_logger,
    setup_logging,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _reset_root_logger():
    """Ensure root logger state is clean before and after each test."""
    root = logging.getLogger()
    original_handlers = list(root.handlers)
    original_level = root.level
    yield
    root.handlers = original_handlers
    root.setLevel(original_level)


@pytest.fixture
def formatter_shanghai() -> TimezoneFormatter:
    """TimezoneFormatter configured for Asia/Shanghai (UTC+8)."""
    return TimezoneFormatter(timezone_str="Asia/Shanghai")


@pytest.fixture
def formatter_utc() -> TimezoneFormatter:
    """TimezoneFormatter configured for UTC."""
    return TimezoneFormatter(timezone_str="UTC")


@pytest.fixture
def formatter_no_tz() -> TimezoneFormatter:
    """TimezoneFormatter with no timezone configured."""
    return TimezoneFormatter()


@pytest.fixture
def log_dir(tmp_path) -> Path:
    """Temporary directory for log files."""
    return tmp_path / "test_logs"


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------


def _make_record(
    message: str = "test",
    name: str = "test.logger",
    level: int = logging.INFO,
    created: float | None = None,
) -> logging.LogRecord:
    """Build a minimal LogRecord for testing."""
    record = logging.LogRecord(
        name=name,
        level=level,
        pathname="test.py",
        lineno=1,
        msg=message,
        args=(),
        exc_info=None,
    )
    if created is not None:
        record.created = created
    return record


# ===========================================================================
# TimezoneFormatter
# ===========================================================================


class TestTimezoneFormatter:
    """Tests for TimezoneFormatter.formatTime and offset resolution."""

    # -- Basic formatting ---------------------------------------------------

    def test_format_time_shanghai_offset(self, formatter_shanghai: TimezoneFormatter):
        """Shanghai formatter applies UTC+8 to the record timestamp."""
        # A fixed UTC epoch: 2025-06-15 06:00:00 UTC
        utc_dt = datetime(2025, 6, 15, 6, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())

        result = formatter_shanghai.formatTime(record)
        # UTC+8 means 06:00 + 8h = 14:00
        assert result == "2025-06-15 14:00:00"

    def test_format_time_utc(self, formatter_utc: TimezoneFormatter):
        """UTC formatter leaves the timestamp unchanged."""
        utc_dt = datetime(2025, 6, 15, 6, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())

        result = formatter_utc.formatTime(record)
        assert result == "2025-06-15 06:00:00"

    def test_format_time_no_timezone(self, formatter_no_tz: TimezoneFormatter):
        """When no timezone is set, the formatter uses raw UTC time."""
        utc_dt = datetime(2025, 6, 15, 6, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())

        result = formatter_no_tz.formatTime(record)
        # No timezone_str -> no offset applied -> raw UTC
        assert result == "2025-06-15 06:00:00"

    def test_format_time_custom_datefmt(self, formatter_shanghai: TimezoneFormatter):
        """A custom datefmt string is respected."""
        utc_dt = datetime(2025, 1, 1, 0, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())

        result = formatter_shanghai.formatTime(record, datefmt="%H:%M")
        # UTC 00:00 + 8h = 08:00
        assert result == "08:00"

    # -- Timezone offset resolution -----------------------------------------

    def test_known_timezone_tokyo(self):
        """Asia/Tokyo resolves to UTC+9."""
        fmt = TimezoneFormatter(timezone_str="Asia/Tokyo")
        utc_dt = datetime(2025, 3, 10, 0, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())
        result = fmt.formatTime(record)
        assert result == "2025-03-10 09:00:00"

    def test_known_timezone_new_york(self):
        """America/New_York resolves to UTC-5."""
        fmt = TimezoneFormatter(timezone_str="America/New_York")
        utc_dt = datetime(2025, 3, 10, 10, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())
        result = fmt.formatTime(record)
        assert result == "2025-03-10 05:00:00"

    def test_utc_plus_offset_string(self):
        """UTC+3 string is parsed correctly."""
        fmt = TimezoneFormatter(timezone_str="UTC+3")
        utc_dt = datetime(2025, 7, 20, 12, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())
        result = fmt.formatTime(record)
        assert result == "2025-07-20 15:00:00"

    def test_utc_minus_offset_string(self):
        """UTC-7 string is parsed correctly."""
        fmt = TimezoneFormatter(timezone_str="UTC-7")
        utc_dt = datetime(2025, 7, 20, 12, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())
        result = fmt.formatTime(record)
        assert result == "2025-07-20 05:00:00"

    def test_unknown_timezone_falls_back_to_shanghai(self):
        """Unknown timezone strings fall back to the Shanghai offset (UTC+8)."""
        fmt = TimezoneFormatter(timezone_str="Mars/OlympusMons")
        # _get_timezone_offset should return SHANGHAI_OFFSET
        offset = fmt._get_timezone_offset("Mars/OlympusMons")
        assert offset == SHANGHAI_OFFSET

    # -- Full format output -------------------------------------------------

    def test_full_format_contains_level_and_message(self, formatter_shanghai: TimezoneFormatter):
        """The full formatted log line contains level name and message."""
        fmt_str = "[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s"
        formatter = TimezoneFormatter(fmt=fmt_str, timezone_str="UTC")
        record = _make_record(message="hello world", level=logging.WARNING)

        result = formatter.format(record)
        assert "[WARNING]" in result
        assert "hello world" in result

    # -- Edge cases ---------------------------------------------------------

    def test_midnight_cross_with_positive_offset(self):
        """UTC 20:00 + 8h crosses midnight to next day."""
        fmt = TimezoneFormatter(timezone_str="Asia/Shanghai")
        utc_dt = datetime(2025, 12, 31, 20, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())
        result = fmt.formatTime(record)
        assert result == "2026-01-01 04:00:00"

    def test_midnight_cross_with_negative_offset(self):
        """UTC 02:00 - 5h goes back to previous day."""
        fmt = TimezoneFormatter(timezone_str="America/New_York")
        utc_dt = datetime(2025, 1, 1, 2, 0, 0, tzinfo=UTC)
        record = _make_record(created=utc_dt.timestamp())
        result = fmt.formatTime(record)
        assert result == "2024-12-31 21:00:00"


# ===========================================================================
# setup_logging
# ===========================================================================


class TestSetupLogging:
    """Tests for the setup_logging function."""

    def test_creates_log_directory(self, log_dir: Path):
        """setup_logging creates the log directory if it does not exist."""
        assert not log_dir.exists()
        setup_logging(log_dir=str(log_dir))
        assert log_dir.exists()
        assert log_dir.is_dir()

    def test_creates_nested_log_directory(self, tmp_path: Path):
        """setup_logging creates parent directories as needed."""
        nested = tmp_path / "deep" / "nested" / "logs"
        setup_logging(log_dir=str(nested))
        assert nested.exists()

    def test_root_logger_level_info(self, log_dir: Path):
        """Root logger is set to INFO level."""
        setup_logging(log_level="INFO", log_dir=str(log_dir))
        assert logging.getLogger().level == logging.INFO

    def test_root_logger_level_debug(self, log_dir: Path):
        """Root logger is set to DEBUG level."""
        setup_logging(log_level="DEBUG", log_dir=str(log_dir))
        assert logging.getLogger().level == logging.DEBUG

    def test_root_logger_level_warning(self, log_dir: Path):
        """Root logger is set to WARNING level."""
        setup_logging(log_level="WARNING", log_dir=str(log_dir))
        assert logging.getLogger().level == logging.WARNING

    def test_root_logger_level_error(self, log_dir: Path):
        """Root logger is set to ERROR level."""
        setup_logging(log_level="ERROR", log_dir=str(log_dir))
        assert logging.getLogger().level == logging.ERROR

    def test_root_logger_level_case_insensitive(self, log_dir: Path):
        """Log level string is case-insensitive."""
        setup_logging(log_level="debug", log_dir=str(log_dir))
        assert logging.getLogger().level == logging.DEBUG

    def test_invalid_level_defaults_to_info(self, log_dir: Path):
        """An unrecognized log level string falls back to INFO."""
        setup_logging(log_level="NONEXISTENT", log_dir=str(log_dir))
        # getattr(logging, "NONEXISTENT", logging.INFO) -> logging.INFO
        assert logging.getLogger().level == logging.INFO

    def test_clears_existing_handlers(self, log_dir: Path):
        """setup_logging clears pre-existing handlers on the root logger."""
        root = logging.getLogger()
        root.addHandler(logging.StreamHandler())
        assert len(root.handlers) >= 1

        setup_logging(log_dir=str(log_dir))
        # Should have 3 handlers: console, file, error-file
        assert len(root.handlers) == 3

    def test_has_three_handlers(self, log_dir: Path):
        """After setup, the root logger has exactly 3 handlers."""
        setup_logging(log_dir=str(log_dir))
        assert len(logging.getLogger().handlers) == 3

    def test_console_handler_type(self, log_dir: Path):
        """First handler is a StreamHandler (console)."""
        setup_logging(log_dir=str(log_dir))
        handler = logging.getLogger().handlers[0]
        assert isinstance(handler, logging.StreamHandler)
        assert not isinstance(handler, logging.handlers.TimedRotatingFileHandler)

    def test_console_handler_level_matches_root(self, log_dir: Path):
        """Console handler level matches the configured log level."""
        setup_logging(log_level="DEBUG", log_dir=str(log_dir))
        assert logging.getLogger().handlers[0].level == logging.DEBUG

    def test_file_handler_is_timed_rotating(self, log_dir: Path):
        """Second handler is a TimedRotatingFileHandler."""
        setup_logging(log_dir=str(log_dir))
        handler = logging.getLogger().handlers[1]
        assert isinstance(handler, logging.handlers.TimedRotatingFileHandler)

    def test_file_handler_rotates_at_midnight(self, log_dir: Path):
        """File handler rotates at midnight."""
        setup_logging(log_dir=str(log_dir))
        handler = logging.getLogger().handlers[1]
        assert handler.when.upper() == "MIDNIGHT"
        assert handler.interval == 86400  # midnight interval is in seconds

    def test_file_handler_suffix_is_date(self, log_dir: Path):
        """File handler suffix is configured for date-based naming."""
        setup_logging(log_dir=str(log_dir))
        handler = logging.getLogger().handlers[1]
        assert handler.suffix == "%Y-%m-%d"

    def test_file_handler_retention(self, log_dir: Path):
        """File handler backupCount matches retention_days."""
        setup_logging(retention_days=7, log_dir=str(log_dir))
        handler = logging.getLogger().handlers[1]
        assert handler.backupCount == 7

    def test_file_handler_encoding_utf8(self, log_dir: Path):
        """File handler uses UTF-8 encoding."""
        setup_logging(log_dir=str(log_dir))
        handler = logging.getLogger().handlers[1]
        assert handler.encoding == "utf-8"

    def test_file_handler_uses_formatter(self, log_dir: Path):
        """File handler has a TimezoneFormatter set."""
        setup_logging(log_dir=str(log_dir))
        handler = logging.getLogger().handlers[1]
        assert isinstance(handler.formatter, TimezoneFormatter)

    def test_error_handler_level_is_error(self, log_dir: Path):
        """The error file handler has level ERROR regardless of root level."""
        setup_logging(log_level="DEBUG", log_dir=str(log_dir))
        error_handler = logging.getLogger().handlers[2]
        assert error_handler.level == logging.ERROR

    def test_error_handler_is_timed_rotating(self, log_dir: Path):
        """Error handler is also a TimedRotatingFileHandler."""
        setup_logging(log_dir=str(log_dir))
        handler = logging.getLogger().handlers[2]
        assert isinstance(handler, logging.handlers.TimedRotatingFileHandler)

    def test_error_handler_retention(self, log_dir: Path):
        """Error handler backupCount matches retention_days."""
        setup_logging(retention_days=14, log_dir=str(log_dir))
        handler = logging.getLogger().handlers[2]
        assert handler.backupCount == 14

    def test_log_file_paths(self, log_dir: Path):
        """Log files are created in the specified directory with expected names."""
        setup_logging(log_dir=str(log_dir), app_name="myapp")
        # Trigger a log to ensure file creation
        logging.getLogger("test.filepath").info("force file creation")
        # Flush handlers so the file is written
        for h in logging.getLogger().handlers:
            h.flush()

        # Normal log file: myapp.log
        assert (log_dir / "myapp.log").exists()
        # Error log file: myapp_error.log
        assert (log_dir / "myapp_error.log").exists()

    def test_custom_app_name(self, log_dir: Path):
        """Custom app_name is used for log file naming."""
        setup_logging(log_dir=str(log_dir), app_name="custom")
        logging.getLogger("test.custom").info("write")
        for h in logging.getLogger().handlers:
            h.flush()

        assert (log_dir / "custom.log").exists()
        assert (log_dir / "custom_error.log").exists()

    def test_default_app_name(self, log_dir: Path):
        """Default app_name is 'app'."""
        setup_logging(log_dir=str(log_dir))
        logging.getLogger("test.default").info("write")
        for h in logging.getLogger().handlers:
            h.flush()

        assert (log_dir / "app.log").exists()
        assert (log_dir / "app_error.log").exists()

    def test_all_handlers_share_formatter(self, log_dir: Path):
        """All three handlers have a TimezoneFormatter."""
        setup_logging(log_dir=str(log_dir), timezone="UTC")
        for handler in logging.getLogger().handlers:
            assert isinstance(handler.formatter, TimezoneFormatter)

    def test_formatter_timezone_propagated(self, log_dir: Path):
        """The formatter on each handler uses the specified timezone."""
        setup_logging(log_dir=str(log_dir), timezone="Asia/Tokyo")
        for handler in logging.getLogger().handlers:
            assert handler.formatter.timezone_str == "Asia/Tokyo"


# ===========================================================================
# Third-party noise suppression
# ===========================================================================


class TestThirdPartyNoiseSuppression:
    """Tests that third-party library loggers are quieted."""

    NOISY_LOGGERS = [
        "uvicorn.access",
        "uvicorn.error",
        "gunicorn.access",
        "gunicorn.error",
        "sqlalchemy.engine",
        "celery",
        "httpx",
        "httpcore",
    ]

    @pytest.fixture(autouse=True)
    def _setup(self, tmp_path: Path):
        """Run setup_logging before each test."""
        setup_logging(log_dir=str(tmp_path / "logs"))

    @pytest.mark.parametrize("logger_name", NOISY_LOGGERS)
    def test_noisy_logger_suppressed(self, logger_name: str):
        """Third-party loggers are set to WARNING or ERROR."""
        level = logging.getLogger(logger_name).level
        assert level >= logging.WARNING, (
            f"{logger_name} level {level} should be >= WARNING ({logging.WARNING})"
        )

    def test_uvicorn_access_is_warning(self):
        """uvicorn.access is set to WARNING."""
        assert logging.getLogger("uvicorn.access").level == logging.WARNING

    def test_uvicorn_error_is_error(self):
        """uvicorn.error is set to ERROR."""
        assert logging.getLogger("uvicorn.error").level == logging.ERROR

    def test_sqlalchemy_is_warning(self):
        """sqlalchemy.engine is set to WARNING."""
        assert logging.getLogger("sqlalchemy.engine").level == logging.WARNING

    def test_celery_is_warning(self):
        """celery is set to WARNING."""
        assert logging.getLogger("celery").level == logging.WARNING

    def test_httpx_is_warning(self):
        """httpx is set to WARNING."""
        assert logging.getLogger("httpx").level == logging.WARNING

    def test_httpcore_is_warning(self):
        """httpcore is set to WARNING."""
        assert logging.getLogger("httpcore").level == logging.WARNING


# ===========================================================================
# Log level filtering (caplog-based integration)
# ===========================================================================


class TestLogLevelFiltering:
    """Integration tests that log messages are filtered by level.

    Uses file content (not caplog) because setup_logging clears root handlers,
    which removes caplog's capture handler.
    """

    def _read_normal_log(self, log_dir: Path) -> str:
        return (log_dir / "app.log").read_text(encoding="utf-8")

    def test_info_level_captures_info_and_above(self, log_dir: Path):
        """At INFO level, DEBUG messages are suppressed."""
        setup_logging(log_level="INFO", log_dir=str(log_dir))
        logger = logging.getLogger("test.filtering")

        logger.debug("debug-msg")
        logger.info("info-msg")
        logger.warning("warn-msg")

        for h in logging.getLogger().handlers:
            h.flush()

        content = self._read_normal_log(log_dir)
        assert "debug-msg" not in content
        assert "info-msg" in content
        assert "warn-msg" in content

    def test_warning_level_suppresses_info(self, log_dir: Path):
        """At WARNING level, INFO messages are suppressed."""
        setup_logging(log_level="WARNING", log_dir=str(log_dir))
        logger = logging.getLogger("test.filtering2")

        logger.info("info-msg")
        logger.warning("warn-msg")

        for h in logging.getLogger().handlers:
            h.flush()

        content = self._read_normal_log(log_dir)
        assert "info-msg" not in content
        assert "warn-msg" in content

    def test_error_level_only_shows_errors(self, log_dir: Path):
        """At ERROR level, only ERROR and CRITICAL messages appear."""
        setup_logging(log_level="ERROR", log_dir=str(log_dir))
        logger = logging.getLogger("test.filtering3")

        logger.info("info-msg")
        logger.warning("warn-msg")
        logger.error("error-msg")
        logger.critical("critical-msg")

        for h in logging.getLogger().handlers:
            h.flush()

        content = self._read_normal_log(log_dir)
        assert "info-msg" not in content
        assert "warn-msg" not in content
        assert "error-msg" in content
        assert "critical-msg" in content

    def test_debug_level_captures_all(self, log_dir: Path):
        """At DEBUG level, all messages are captured."""
        setup_logging(log_level="DEBUG", log_dir=str(log_dir))
        logger = logging.getLogger("test.filtering4")

        logger.debug("debug-msg")
        logger.info("info-msg")
        logger.warning("warn-msg")
        logger.error("error-msg")

        for h in logging.getLogger().handlers:
            h.flush()

        content = self._read_normal_log(log_dir)
        assert "debug-msg" in content
        assert "info-msg" in content
        assert "warn-msg" in content
        assert "error-msg" in content


# ===========================================================================
# Log file content
# ===========================================================================


class TestLogFileContent:
    """Tests that log files actually receive content."""

    def test_normal_log_receives_info(self, log_dir: Path):
        """An INFO message is written to the normal log file."""
        setup_logging(log_dir=str(log_dir), log_level="INFO")
        logger = logging.getLogger("test.filecontent")
        logger.info("test-info-message")

        # Flush to ensure content is written
        for h in logging.getLogger().handlers:
            h.flush()

        content = (log_dir / "app.log").read_text(encoding="utf-8")
        assert "test-info-message" in content

    def test_error_log_receives_errors_only(self, log_dir: Path):
        """Only ERROR-level messages are written to the error log file."""
        setup_logging(log_dir=str(log_dir), log_level="DEBUG")
        logger = logging.getLogger("test.errorfile")
        logger.info("info-not-in-error")
        logger.error("error-yes-in-error")

        for h in logging.getLogger().handlers:
            h.flush()

        error_content = (log_dir / "app_error.log").read_text(encoding="utf-8")
        assert "error-yes-in-error" in error_content
        assert "info-not-in-error" not in error_content

    def test_log_format_contains_expected_fields(self, log_dir: Path):
        """Log lines contain [asctime], [levelname], [name:lineno]."""
        setup_logging(log_dir=str(log_dir), log_level="INFO")
        logger = logging.getLogger("test.formatcheck")
        logger.info("format-check")

        for h in logging.getLogger().handlers:
            h.flush()

        content = (log_dir / "app.log").read_text(encoding="utf-8")
        line = [l for l in content.splitlines() if "format-check" in l][0]
        # Format: [asctime] [levelname] [name:lineno] message
        assert "[INFO]" in line
        assert "[test.formatcheck:" in line
        assert "format-check" in line

    def test_log_file_encoding_utf8(self, log_dir: Path):
        """UTF-8 characters (Chinese) are written correctly."""
        setup_logging(log_dir=str(log_dir), log_level="INFO")
        logger = logging.getLogger("test.utf8")
        logger.info("日志测试 - UTF-8 中文内容")

        for h in logging.getLogger().handlers:
            h.flush()

        content = (log_dir / "app.log").read_text(encoding="utf-8")
        assert "日志测试" in content
        assert "UTF-8 中文内容" in content


# ===========================================================================
# get_logger / create_logger
# ===========================================================================


class TestGetLogger:
    """Tests for the get_logger and create_logger helper functions."""

    def test_get_logger_returns_named_logger(self):
        """get_logger returns a logger with the given name."""
        logger = get_logger("my.module")
        assert logger.name == "my.module"

    def test_create_logger_returns_named_logger(self):
        """create_logger returns a logger with the given name."""
        logger = create_logger("another.module")
        assert logger.name == "another.module"

    def test_get_logger_returns_logging_logger(self):
        """Returned object is a proper logging.Logger instance."""
        logger = get_logger("test")
        assert isinstance(logger, logging.Logger)


# ===========================================================================
# get_log_files
# ===========================================================================


class TestGetLogFiles:
    """Tests for the get_log_files helper."""

    def test_empty_directory(self, tmp_path: Path):
        """Returns empty lists when no log files exist."""
        result = get_log_files(log_dir=str(tmp_path), app_name="app")
        assert result == {"normal": [], "error": []}

    def test_nonexistent_directory(self, tmp_path: Path):
        """Returns empty lists when the directory does not exist."""
        result = get_log_files(log_dir=str(tmp_path / "nope"), app_name="app")
        assert result == {"normal": [], "error": []}

    def test_finds_normal_logs(self, tmp_path: Path):
        """Finds and returns normal log files matching the app name pattern."""
        (tmp_path / "app-2025-06-15.log").touch()
        (tmp_path / "app-2025-06-16.log").touch()
        (tmp_path / "other-2025-06-15.log").touch()

        result = get_log_files(log_dir=str(tmp_path), app_name="app")
        assert len(result["normal"]) == 2
        assert len(result["error"]) == 0

    def test_finds_error_logs(self, tmp_path: Path):
        """Finds and returns error log files matching the app error pattern."""
        (tmp_path / "app_2025-06-15-error.log").touch()
        (tmp_path / "app_2025-06-16-error.log").touch()

        result = get_log_files(log_dir=str(tmp_path), app_name="app")
        assert len(result["error"]) == 2
        assert len(result["normal"]) == 0

    def test_separates_normal_from_error(self, tmp_path: Path):
        """Normal and error log files are correctly separated."""
        (tmp_path / "app-2025-06-15.log").touch()
        (tmp_path / "app_2025-06-15-error.log").touch()

        result = get_log_files(log_dir=str(tmp_path), app_name="app")
        assert len(result["normal"]) == 1
        assert len(result["error"]) == 1

    def test_custom_app_name(self, tmp_path: Path):
        """Uses the custom app_name to match log files."""
        (tmp_path / "myapp-2025-06-15.log").touch()
        (tmp_path / "app-2025-06-15.log").touch()

        result = get_log_files(log_dir=str(tmp_path), app_name="myapp")
        assert len(result["normal"]) == 1
        assert "myapp-2025-06-15.log" in result["normal"][0]


# ===========================================================================
# Defaults and constants
# ===========================================================================


class TestDefaults:
    """Tests verifying module-level default constants."""

    def test_default_log_dir(self):
        assert DEFAULT_LOG_DIR == "logs"

    def test_default_log_level(self):
        assert DEFAULT_LOG_LEVEL == "INFO"

    def test_default_retention_days(self):
        assert DEFAULT_RETENTION_DAYS == 30

    def test_default_timezone(self):
        assert DEFAULT_TIMEZONE == "Asia/Shanghai"

    def test_shanghai_offset(self):
        assert SHANGHAI_OFFSET == 8
