# 使用官方基础镜像
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    PYTHONUTF8=1 \
    LANG=C.UTF-8 \
    PATH="/app/.venv/bin:${PATH}" \
    UV_LINK_MODE=copy \
    UV_PYTHON=/usr/local/bin/python3.11 \
    UV_PYTHON_DOWNLOADS=never \
    UV_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    UV_EXTRA_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple

# 配置国内 Debian 镜像源（清华大学）
RUN sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources \
    && sed -i 's/security.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list.d/debian.sources

# Configure apt to use mirrors and retry on failure
RUN echo "Acquire::Retries \"3\";" > /etc/apt/apt.conf.d/80-retries \
    && echo "Acquire::http::Timeout \"30\";" > /etc/apt/apt.conf.d/80-timeout

# Install system dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        curl \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Set work directory
WORKDIR /app

# Copy dependency metadata first
COPY pyproject.toml uv.lock ./

# Configure pip to use Chinese mirrors for faster downloads
RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
    && pip config set global.trusted-host pypi.tuna.tsinghua.edu.cn

# Install uv first (faster than regular pip for Python package management)
RUN pip install --no-cache-dir uv

# Pre-install locked third-party dependencies for better layer reuse
RUN uv sync --frozen --no-dev --no-install-project

# Copy application code
COPY . .

# Install the project itself from the locked uv environment
RUN uv sync --frozen --no-dev --no-editable

# Create directories with proper permissions
RUN mkdir -p uploads logs data storage/podcasts temp/transcription

# Copy entrypoint script (must be done before USER switch)
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Create non-root user
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app

# Set entrypoint to fix permissions at runtime (runs as root, then switches to app)
# Entrypoint runs as root to fix permissions, then uses su-exec to run as app user
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Expose port
EXPOSE 8000

# Default command (will be run as app user by entrypoint)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1", "--timeout-keep-alive", "60"]
