#!/bin/bash
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# Check .env file
if [ ! -f "${DIR}/.env" ]; then
    echo "[Init] File .env not found, creating from .env.example..."
    cp "${DIR}/.env.example" "${DIR}/.env"
fi

# Load variables from .env
set -a
source "${DIR}/.env"
set +a

# Set default values if not present
MEDIA_SERVER_ID="${MEDIA_SERVER_ID:-zlm_node_02}"
SECRET="${SECRET:-su6TiedN2rVAmBbIDX0aa0QTiBJLBdcf}"
WVP_HOST="${WVP_HOST:-127.0.0.1}"
WVP_PORT="${WVP_PORT:-18978}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTP_SSL_PORT="${HTTP_SSL_PORT:-0}"
RTSP_PORT="${RTSP_PORT:-554}"
RTMP_PORT="${RTMP_PORT:-1935}"
RTP_PORT="${RTP_PORT:-10000}"
RTC_PORT="${RTC_PORT:-8000}"
SRT_PORT="${SRT_PORT:-9000}"
RTP_PORT_RANGE="${RTP_PORT_RANGE:-30000-30500}"
VIDEO_STORAGE_PATH="${VIDEO_STORAGE_PATH:-/data/video}"
LOG_STORAGE_PATH="${LOG_STORAGE_PATH:-/data/logs}"

CONF_DIR="${DIR}/conf"
CONF_FILE="${CONF_DIR}/config.ini"
TEMPLATE_FILE="${DIR}/config.template.ini"

echo "================================================================="
echo "       DEPLOYING ZLMEDIANODE (STANDALONE HOST-MODE)"
echo "================================================================="
echo " Node ID        : ${MEDIA_SERVER_ID}"
echo " Secret Key     : ${SECRET}"
echo " WVP Master     : http://${WVP_HOST}:${WVP_PORT}"
echo " HTTP Port      : ${HTTP_PORT}"
echo " RTSP Port      : ${RTSP_PORT}"
echo " RTMP Port      : ${RTMP_PORT}"
echo " RTP Port       : ${RTP_PORT}"
echo " RTC Port       : ${RTC_PORT}"
echo " SRT Port       : ${SRT_PORT}"
echo " RTP Range      : ${RTP_PORT_RANGE}"
echo " Video Storage  : ${VIDEO_STORAGE_PATH}"
echo "================================================================="

# 1. Create directories
mkdir -p "$CONF_DIR"
mkdir -p "$VIDEO_STORAGE_PATH" 2>/dev/null || sudo mkdir -p "$VIDEO_STORAGE_PATH"
mkdir -p "$LOG_STORAGE_PATH" 2>/dev/null || sudo mkdir -p "$LOG_STORAGE_PATH"

# 2. Auto-generate config.ini from template
echo "[1/3] Auto-generating ${CONF_FILE}..."
sed \
    -e "s|\${MEDIA_SERVER_ID}|${MEDIA_SERVER_ID}|g" \
    -e "s|\${SECRET}|${SECRET}|g" \
    -e "s|\${WVP_HOST}|${WVP_HOST}|g" \
    -e "s|\${WVP_PORT}|${WVP_PORT}|g" \
    -e "s|\${HTTP_PORT}|${HTTP_PORT}|g" \
    -e "s|\${HTTP_SSL_PORT}|${HTTP_SSL_PORT}|g" \
    -e "s|\${RTSP_PORT}|${RTSP_PORT}|g" \
    -e "s|\${RTMP_PORT}|${RTMP_PORT}|g" \
    -e "s|\${RTP_PORT}|${RTP_PORT}|g" \
    -e "s|\${RTC_PORT}|${RTC_PORT}|g" \
    -e "s|\${SRT_PORT}|${SRT_PORT}|g" \
    -e "s|\${RTP_PORT_RANGE}|${RTP_PORT_RANGE}|g" \
    "$TEMPLATE_FILE" > "$CONF_FILE"

echo "[2/3] Configuration generated successfully."

# 3. Start Docker Compose with Host Network
echo "[3/3] Starting Docker container zlm_${MEDIA_SERVER_ID}..."
docker compose -f "${DIR}/docker-compose.yml" down 2>/dev/null || true
docker compose -f "${DIR}/docker-compose.yml" up -d

echo ""
echo "================================================================="
echo " 🎉 ZLMediaKit Node [${MEDIA_SERVER_ID}] started successfully!"
echo "================================================================="
echo " 👉 Next Step (Add this Node to WVP Master Web):"
echo "   1. Open WVP Web -> Media node -> Add node"
echo "   2. IP: <IP_OF_THIS_SERVER>"
echo "   3. HTTP Port: ${HTTP_PORT}"
echo "   4. Secret: ${SECRET}"
echo "   5. Click [Test] -> Click [Next step] -> Save"
echo "================================================================="
