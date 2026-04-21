#!/bin/bash
# =============================================================================
# Docker Entrypoint Script
# =============================================================================
# This script ensures proper permissions for mounted volumes at runtime
# 确保运行时挂载卷的权限正确

set -e

APP_USER=${APP_USER:-app}

echo "🔧 Fixing permissions for mounted volumes..."
echo "   User: $APP_USER"

# Fix permissions for directories that may be mounted from host
# 修复可能从宿主机挂载的目录权限
DIRECTORIES_TO_FIX=(
    "/app/temp/transcription"
    "/app/storage/podcasts"
    "/app/uploads"
    "/app/logs"
    "/app/data"
)

for dir in "${DIRECTORIES_TO_FIX[@]}"; do
    if [ -d "$dir" ]; then
        # Check if directory is owned by root (which happens with volume mounts)
        current_owner=$(stat -c '%u' "$dir" 2>/dev/null || echo "0")
        if [ "$current_owner" = "0" ]; then
            echo "   📁 Fixing ownership: $dir"
            chown -R $APP_USER:$APP_USER "$dir" 2>/dev/null || true
            chmod -R 775 "$dir" 2>/dev/null || true
        fi
    else
        # Create directory if it doesn't exist
        echo "   📁 Creating: $dir"
        mkdir -p "$dir" 2>/dev/null || true
        chown -R $APP_USER:$APP_USER "$dir" 2>/dev/null || true
        chmod -R 775 "$dir" 2>/dev/null || true
    fi
done

echo "✅ Permission setup complete"
echo ""

# Auto-run database migrations
echo "📦 Running database migrations..."
alembic upgrade head
echo "✅ Migrations complete"
echo ""

# Get app user's home directory
APP_HOME=$(getent passwd "$APP_USER" | cut -d: -f6)

# Execute the main command as app user
# Set HOME and other important environment variables
# 使用 setpriv 或 su（不带 login shell）切换用户执行命令
if command -v setpriv >/dev/null 2>&1; then
    # setpriv is cleaner - it doesn't fork a shell
    export HOME="$APP_HOME"
    exec setpriv --reuid=$APP_USER --regid=$APP_USER --init-groups "$@"
else
    # su without - (no login shell) to avoid environment pollution
    # Set HOME environment variable explicitly to avoid PostgreSQL client looking in /root
    exec su -s /bin/bash - "$APP_USER" -c "export HOME=$APP_HOME; exec $*"
fi
