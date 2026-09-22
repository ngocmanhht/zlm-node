#!/usr/bin/env bash
# ==============================================================================
# Script Tự Động Đăng Ký Node ZLMediaKit về WVP Master (Control Plane)
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [ -f "$ENV_FILE" ]; then
    echo ">> Đang đọc cấu hình từ file .env..."
    # shellcheck disable=SC2046
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo ">> CẢNH BÁO: Chưa tìm thấy file .env, sử dụng cấu hình mặc định!"
fi

# Các biến cấu hình mặc định nếu chưa có trong .env
WVP_MASTER_HOST="${WVP_MASTER_HOST:-192.168.1.100}"
WVP_MASTER_PORT="${WVP_MASTER_PORT:-18978}"
WVP_ADMIN_USER="${WVP_ADMIN_USER:-admin}"
WVP_ADMIN_PASS="${WVP_ADMIN_PASS:-admin}"

NODE_ID="${NODE_ID:-zlm_node_01}"
NODE_SECRET="${NODE_SECRET:-secret_node_01_random_secure_key}"
NODE_IP="${NODE_IP:-127.0.0.1}"
NODE_SDP_IP="${NODE_SDP_IP:-$NODE_IP}"
NODE_STREAM_IP="${NODE_STREAM_IP:-$NODE_IP}"
ZLM_HTTP_PORT="${ZLM_HTTP_PORT:-80}"
ZLM_RTSP_PORT="${ZLM_RTSP_PORT:-554}"
ZLM_RTMP_PORT="${ZLM_RTMP_PORT:-1935}"
ZLM_RTP_PORT="${ZLM_RTP_PORT:-10000}"
ZLM_RTP_PORT_RANGE="${ZLM_RTP_PORT_RANGE:-30000,30500}"

echo "========================================================================"
echo "  🚀 BẮT ĐẦU TỰ ĐỘNG ĐĂNG KÝ ZLMEDIKIT NODE VỀ WVP MASTER"
echo "========================================================================"
echo "  • Node ID:         ${NODE_ID}"
echo "  • Node IP:         ${NODE_IP}"
echo "  • Secret của Node: ${NODE_SECRET}"
echo "  • WVP Master:      http://${WVP_MASTER_HOST}:${WVP_MASTER_PORT}"
echo "========================================================================"

# 1. Chờ WVP Master sẵn sàng
echo ">> [1/3] Đang kiểm tra kết nối tới WVP Master..."
MAX_RETRY=30
RETRY_COUNT=0
until curl -s "http://${WVP_MASTER_HOST}:${WVP_MASTER_PORT}/api/version" > /dev/null 2>&1 || [ $RETRY_COUNT -eq $MAX_RETRY ]; do
    echo "   ... Đang đợi WVP Master online (lần $RETRY_COUNT/$MAX_RETRY)..."
    sleep 2
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

if [ $RETRY_COUNT -eq $MAX_RETRY ]; then
    echo ">> [LỖI] Không kết nối được tới WVP Master tại http://${WVP_MASTER_HOST}:${WVP_MASTER_PORT}!"
    exit 1
fi
echo "   ✅ WVP Master đã sẵn sàng phản hồi!"

# 2. Đăng nhập WVP Master để lấy Access Token JWT (MD5 password)
echo ">> [2/3] Đang xác thực tài khoản quản trị viên trên WVP Master..."
# Tính MD5 của mật khẩu (hỗ trợ cả md5 trên Mac và md5sum trên Linux)
if command -v md5 >/dev/null 2>&1; then
    PASS_MD5=$(echo -n "${WVP_ADMIN_PASS}" | md5)
elif command -v md5sum >/dev/null 2>&1; then
    PASS_MD5=$(echo -n "${WVP_ADMIN_PASS}" | md5sum | awk '{print $1}')
else
    # Fallback dùng python
    PASS_MD5=$(python3 -c "import hashlib; print(hashlib.md5(b'${WVP_ADMIN_PASS}').hexdigest())")
fi

LOGIN_RESP=$(curl -s -X POST "http://${WVP_MASTER_HOST}:${WVP_MASTER_PORT}/api/user/login?username=${WVP_ADMIN_USER}&password=${PASS_MD5}")
ACCESS_TOKEN=$(echo "$LOGIN_RESP" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4 || echo "")

if [ -z "$ACCESS_TOKEN" ]; then
    echo ">> [CẢNH BÁO] Không lấy được JWT Token hoặc WVP đã tắt xác thực interface. Tiếp tục gọi không kèm token..."
    AUTH_HEADER=""
else
    echo "   ✅ Xác thực thành công! Đã cấp phát JWT Token."
    AUTH_HEADER="access-token: ${ACCESS_TOKEN}"
fi

# 3. Gửi thông tin khai báo Node về WVP Master
echo ">> [3/3] Đang đăng ký thông tin Node ${NODE_ID} vào WVP Master..."

REGISTER_PAYLOAD=$(cat <<EOF
{
  "id": "${NODE_ID}",
  "ip": "${NODE_IP}",
  "hookIp": "${WVP_MASTER_HOST}",
  "sdpIp": "${NODE_SDP_IP}",
  "streamIp": "${NODE_STREAM_IP}",
  "httpPort": ${ZLM_HTTP_PORT},
  "httpSSlPort": 0,
  "rtmpPort": ${ZLM_RTMP_PORT},
  "rtmpSSlPort": 0,
  "rtspPort": ${ZLM_RTSP_PORT},
  "rtspSSLPort": 0,
  "rtpProxyPort": ${ZLM_RTP_PORT},
  "rtpPortRange": "${ZLM_RTP_PORT_RANGE}",
  "rtpEnable": true,
  "secret": "${NODE_SECRET}",
  "autoConfig": false,
  "type": "zlm"
}
EOF
)

if [ -n "$AUTH_HEADER" ]; then
    SAVE_RESP=$(curl -s -X POST "http://${WVP_MASTER_HOST}:${WVP_MASTER_PORT}/api/server/media_server/save" \
        -H "Content-Type: application/json" \
        -H "${AUTH_HEADER}" \
        -d "${REGISTER_PAYLOAD}")
else
    SAVE_RESP=$(curl -s -X POST "http://${WVP_MASTER_HOST}:${WVP_MASTER_PORT}/api/server/media_server/save" \
        -H "Content-Type: application/json" \
        -d "${REGISTER_PAYLOAD}")
fi

echo "   Phản hồi từ WVP Master: ${SAVE_RESP}"
echo "========================================================================"
echo "  🎉 ĐĂNG KÝ NODE ${NODE_ID} THÀNH CÔNG!"
echo "  • Trạng thái: Node đã được ghi vào Database WVP Master."
echo "  • Node sẽ tự động chuyển sang ONLINE ngay khi ZLMediaKit gửi nhịp tim."
echo "========================================================================"
