#!/bin/sh
# Nginx 自动配置脚本 / Nginx Auto-Configuration Script
# 根据是否有 SSL 证书自动选择 HTTP 或 HTTPS 配置
# Automatically selects HTTP or HTTPS config based on SSL certificate availability

set -e

echo "=== Nginx Auto-Configuration ==="

# 清理镜像自带的默认配置文件，避免冲突
# Clean up default config files from the base image to avoid conflicts
echo "🧹 Cleaning up default configurations..."
if [ -f "/etc/nginx/conf.d/default.conf" ]; then
    rm -f /etc/nginx/conf.d/default.conf
    echo "  ✓ Removed: /etc/nginx/conf.d/default.conf"
fi

# 获取环境变量 / Get environment variables
DOMAIN="${DOMAIN:-localhost}"
SSL_CERT_PATH="${SSL_CERT_PATH:-/etc/nginx/cert/fullchain.pem}"
SSL_KEY_PATH="${SSL_KEY_PATH:-/etc/nginx/cert/privkey.pem}"

echo "Domain: ${DOMAIN}"
echo "SSL Certificate: ${SSL_CERT_PATH}"

# 检查 SSL 证书是否存在 / Check if SSL certificate exists
export DOMAIN
export SSL_CERT_PATH
export SSL_KEY_PATH
VARS='${DOMAIN} ${SSL_CERT_PATH} ${SSL_KEY_PATH}'

if [ -f "${SSL_CERT_PATH}" ] && [ -f "${SSL_KEY_PATH}" ]; then
    echo "✅ SSL certificates found - enabling HTTPS mode"

    # 检查证书有效性 / Verify certificate validity
    if openssl x509 -in "${SSL_CERT_PATH}" -noout -checkend 0 2>/dev/null; then
        echo "  - SSL certificate is valid"
    else
        echo "  ⚠️  Warning: SSL certificate may be invalid or expired"
    fi

    # 渲染 HTTPS 模板 / Render HTTPS template
    if [ -f "/etc/nginx/templates/default-ssl.conf.template" ]; then
        envsubst "$VARS" < "/etc/nginx/templates/default-ssl.conf.template" > "/etc/nginx/conf.d/default.conf"
        echo "  - Rendered HTTPS template (HTTP + HTTPS)"
    else
        echo "  ❌ Error: default-ssl.conf.template not found!"
        exit 1
    fi

else
    echo "ℹ️  No SSL certificates found - using HTTP only mode"

    # 渲染 HTTP 模板 / Render HTTP template
    if [ -f "/etc/nginx/templates/default.conf.template" ]; then
        envsubst "$VARS" < "/etc/nginx/templates/default.conf.template" > "/etc/nginx/conf.d/default.conf"
        echo "  - Rendered HTTP template"
    else
        echo "  ❌ Error: default.conf.template not found!"
        exit 1
    fi
fi

# 禁用官方预置的 envsubst 脚本，防止二次渲染导致冲突 / Disable official envsubst
rm -f /docker-entrypoint.d/20-envsubst-on-templates.sh 2>/dev/null || true
echo "  - Disabled official Nginx envsubst script"

# 列出当前激活的模板 / List active templates
echo ""
echo "Active templates:"
ls -la /etc/nginx/templates/*.template 2>/dev/null | awk '{print "  " $NF}' || echo "  (none found)"

echo ""
echo "=== Configuration complete, starting Nginx ==="
