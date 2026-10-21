#!/usr/bin/env bash
# ==============================================================================
# Deploy ZLMediaKit Standalone Worker Node (Cluster Join Token)
# ==============================================================================

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"

# Ensure directories for volumes exist
mkdir -p "${DIR}/volumes/record" "${DIR}/volumes/log"

# 1. Sinh cấu hình config.ini từ .env
echo ">> [1/2] Đồng bộ file cấu hình config.ini từ .env..."
bash "${DIR}/generate-config.sh"

# 2. Khởi động container ZLMediaKit
echo ">> [2/2] Khởi động container ZLMediaKit..."
docker compose -f "${DIR}/docker-compose.yml" down 2>/dev/null || true
docker compose -f "${DIR}/docker-compose.yml" up -d

echo ""
echo "================================================================="
echo " 🎉 ZLMediaKit Worker Node khởi động thành công!"
echo " • Webhook kèm Cluster Join Token đã được gửi tới WVP Master."
echo " • WVP Master sẽ tự động nhận diện và kích hoạt Node ONLINE."
echo " • Xem log: docker compose -f ${DIR}/docker-compose.yml logs -f"
echo "================================================================="
