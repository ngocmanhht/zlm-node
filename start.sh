#!/usr/bin/env bash
# ==============================================================================
# Script 1-Click: Tạo cấu hình và Khởi động ZLMediaKit Worker Node
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ">> [1/2] Đồng bộ file cấu hình từ .env..."
bash "${SCRIPT_DIR}/generate-config.sh"

echo ">> [2/2] Khởi động ZLMediaKit Node..."
docker compose -f "${SCRIPT_DIR}/docker-compose.yml" up -d

echo "========================================================================"
echo "  🎉 KHỞI ĐỘNG ZLMEDIKIT WORKER NODE THÀNH CÔNG!"
echo "  • Node sẽ tự động gửi webhook kèm Cluster Join Token về WVP Master."
echo "  • WVP Master sẽ tự động lưu Node vào CSDL và kích hoạt ONLINE ngay lập tức."
echo "  • Xem log hoạt động: docker compose logs -f"
echo "========================================================================"
