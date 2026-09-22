#!/usr/bin/env bash
# ==============================================================================
# Entrypoint: Khởi động ZLMediaKit & Tự Động Đăng Ký về WVP Master
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

NODE_ID="${NODE_ID:-zlm_node_01}"
NODE_SECRET="${NODE_SECRET:-secret_node_01_random_secure_key}"
ZLM_HTTP_PORT="${ZLM_HTTP_PORT:-80}"
ZLM_RTSP_PORT="${ZLM_RTSP_PORT:-554}"
ZLM_RTMP_PORT="${ZLM_RTMP_PORT:-1935}"
ZLM_RTP_PORT="${ZLM_RTP_PORT:-10000}"
ZLM_RTP_PORT_RANGE="${ZLM_RTP_PORT_RANGE:-30000,30500}"
WVP_MASTER_HOST="${WVP_MASTER_HOST:-192.168.1.100}"
WVP_MASTER_PORT="${WVP_MASTER_PORT:-18978}"

echo ">> [1/2] Đang tạo file config.ini từ template..."
sed -e "s|\${NODE_SECRET}|${NODE_SECRET}|g" \
    -e "s|\${NODE_ID}|${NODE_ID}|g" \
    -e "s|\${ZLM_HTTP_PORT}|${ZLM_HTTP_PORT}|g" \
    -e "s|\${ZLM_RTSP_PORT}|${ZLM_RTSP_PORT}|g" \
    -e "s|\${ZLM_RTMP_PORT}|${ZLM_RTMP_PORT}|g" \
    -e "s|\${ZLM_RTP_PORT}|${ZLM_RTP_PORT}|g" \
    -e "s|\${ZLM_RTP_PORT_RANGE}|${ZLM_RTP_PORT_RANGE}|g" \
    -e "s|\${WVP_MASTER_HOST}|${WVP_MASTER_HOST}|g" \
    -e "s|\${WVP_MASTER_PORT}|${WVP_MASTER_PORT}|g" \
    "${SCRIPT_DIR}/config.ini.template" > "${SCRIPT_DIR}/config.ini"

echo ">> [2/2] Chạy tiến trình tự động đăng ký trong nền..."
(
    sleep 3
    bash "${SCRIPT_DIR}/register.sh" || true
) &

echo ">> Khởi động ZLMediaKit MediaServer..."
exec MediaServer -c "${SCRIPT_DIR}/config.ini" -l 0
