#!/usr/bin/env bash
# ==============================================================================
# Script sinh cấu hình config.ini từ .env cho Node ZLMediaKit
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo ">> Chưa có file .env! Đang tự động sao chép từ .env.example..."
    cp "${SCRIPT_DIR}/.env.example" "$ENV_FILE"
fi

# shellcheck disable=SC2046
export $(grep -v '^#' "$ENV_FILE" | xargs)

echo ">> Đang tạo cấu hình config.ini cho Node [${NODE_ID:-zlm_node_01}]..."
sed -e "s|\${CLUSTER_JOIN_TOKEN}|${CLUSTER_JOIN_TOKEN}|g" \
    -e "s|\${NODE_SECRET}|${NODE_SECRET}|g" \
    -e "s|\${NODE_ID}|${NODE_ID:-zlm_node_01}|g" \
    -e "s|\${NODE_IP}|${NODE_IP:-127.0.0.1}|g" \
    -e "s|\${NODE_SDP_IP}|${NODE_SDP_IP:-127.0.0.1}|g" \
    -e "s|\${NODE_STREAM_IP}|${NODE_STREAM_IP:-127.0.0.1}|g" \
    -e "s|\${ZLM_HTTP_PORT}|${ZLM_HTTP_PORT:-80}|g" \
    -e "s|\${ZLM_RTSP_PORT}|${ZLM_RTSP_PORT:-554}|g" \
    -e "s|\${ZLM_RTMP_PORT}|${ZLM_RTMP_PORT:-1935}|g" \
    -e "s|\${ZLM_RTP_PORT}|${ZLM_RTP_PORT:-10000}|g" \
    -e "s|\${ZLM_RTP_PORT_RANGE}|${ZLM_RTP_PORT_RANGE:-30000,30500}|g" \
    -e "s|\${WVP_MASTER_HOST}|${WVP_MASTER_HOST:-192.168.1.100}|g" \
    -e "s|\${WVP_MASTER_PORT}|${WVP_MASTER_PORT:-18978}|g" \
    "${SCRIPT_DIR}/config.ini.template" > "${SCRIPT_DIR}/config.ini"

echo ">> ✅ Đã tạo file config.ini thành công!"
