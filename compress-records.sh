#!/usr/bin/env bash
# ==============================================================================
# Script Nén & Resize File Ghi Hình MP4 Offline cho ZLMediaKit Node
# ==============================================================================
# Công dụng:
#   - Quét thư mục ghi hình ./volumes/record/
#   - Tìm các file .mp4 đã hoàn tất (ghi xong > 10 phút trước)
#   - Nén lại bằng FFmpeg (chuẩn H.265/HEVC hoặc H.264 với CRF tối ưu dung lượng)
#   - Tùy chọn downscale resolution (ví dụ về tối đa 720p)
#   - Tiết kiệm 50% - 75% dung lượng lưu trữ trên đĩa cứng
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECORD_DIR="${SCRIPT_DIR}/volumes/record"
ENV_FILE="${SCRIPT_DIR}/.env"

# Tải cấu hình từ .env nếu có
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC2046
    export $(grep -v '^#' "$ENV_FILE" | xargs)
fi

# Cấu hình nén:
# MAX_HEIGHT: 720 (giữ nguyên nếu video nhỏ hơn, resize nếu video là 1080p/2K/4K)
MAX_HEIGHT="${MAX_HEIGHT:-720}"
# TARGET_FPS: Hạ FPS xuống chuẩn giám sát an ninh (15 hoặc 12). Đặt 0 để giữ nguyên FPS gốc.
TARGET_FPS="${TARGET_FPS:-15}"
# DROP_STATIC_FRAMES: true = Tự động bỏ qua các frame tĩnh/không có chuyển động (mpdecimate) để tiết kiệm thêm 20-40% đĩa
DROP_STATIC_FRAMES="${DROP_STATIC_FRAMES:-false}"
# CODEC: libx265 (giảm dung lượng tối đa) hoặc libx264 (tương thích rộng hơn)
CODEC="${CODEC:-libx265}"
# CRF: 28 cho H.265 (tương đương chất lượng tốt, dung lượng cực thấp)
CRF="${CRF:-28}"
# PRESET: ultrafast, superfast, veryfast, faster, fast, medium
PRESET="${PRESET:-veryfast}"
# MIN_AGE_MINUTES: Chỉ nén file đã ghi xong cách đây ít nhất N phút (tránh file đang ghi dở)
MIN_AGE_MINUTES="${MIN_AGE_MINUTES:-15}"

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo ">> [LỖI] Chưa cài đặt FFmpeg trên máy chủ!"
    echo ">> Vui lòng cài đặt: sudo apt install ffmpeg (Ubuntu/Debian) hoặc brew install ffmpeg (macOS)"
    exit 1
fi

if [ ! -d "$RECORD_DIR" ]; then
    echo ">> Không tìm thấy thư mục: $RECORD_DIR"
    exit 0
fi

echo "========================================================================"
echo "  🎬 BẮT ĐẦU QUÉT VÀ NÉN CÁC FILE GHI HÌNH MP4"
echo "  • Thư mục:      $RECORD_DIR"
echo "  • Codec:        $CODEC (CRF: $CRF, Preset: $PRESET)"
echo "  • Max Height:   ${MAX_HEIGHT}p"
echo "  • Target FPS:   ${TARGET_FPS} fps (Drop Static: ${DROP_STATIC_FRAMES})"
echo "  • Điều kiện:    File hoàn thành > ${MIN_AGE_MINUTES} phút trước"
echo "========================================================================"

TOTAL_ORIGINAL=0
TOTAL_COMPRESSED=0
COUNT=0

# Tìm các file mp4 chưa nén
while IFS= read -r file; do
    # Bỏ qua file nếu đã nén rồi
    if [ -f "${file}.done" ]; then
        continue
    fi

    COUNT=$((COUNT + 1))
    ORIG_SIZE=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
    TMP_FILE="${file}.tmp.mp4"

    echo ">> [${COUNT}] Đang nén: $(basename "$file") ($(numfmt --to=iec "$ORIG_SIZE" 2>/dev/null || echo "${ORIG_SIZE} bytes"))..."

    # Xây dựng bộ lọc Video Filter (-vf)
    VF_FILTERS=()
    if [ "$DROP_STATIC_FRAMES" = "true" ]; then
        VF_FILTERS+=("mpdecimate")
    fi
    if [ "$TARGET_FPS" -gt 0 ] 2>/dev/null; then
        VF_FILTERS+=("fps=fps=${TARGET_FPS}")
    fi
    VF_FILTERS+=("scale=-2:'min(${MAX_HEIGHT},ih)'")
    
    # Ghép các filter bằng dấu phẩy
    VF_STRING=$(IFS=,; echo "${VF_FILTERS[*]}")

    # Lệnh FFmpeg nén, hạ FPS và resize
    if ffmpeg -y -hide_banner -loglevel error \
        -i "$file" \
        -vf "$VF_STRING" \
        -c:v "$CODEC" \
        -crf "$CRF" \
        -preset "$PRESET" \
        -c:a aac -b:a 64k \
        "$TMP_FILE"; then

        NEW_SIZE=$(stat -f%z "$TMP_FILE" 2>/dev/null || stat -c%s "$TMP_FILE" 2>/dev/null || echo 0)

        # Chỉ thay thế nếu file nén nhỏ hơn file gốc
        if [ "$NEW_SIZE" -gt 0 ] && [ "$NEW_SIZE" -lt "$ORIG_SIZE" ]; then
            mv "$TMP_FILE" "$file"
            touch "${file}.done"
            SAVED_PERCENT=$(( (ORIG_SIZE - NEW_SIZE) * 100 / ORIG_SIZE ))
            echo "   ✅ Nén thành công: $(numfmt --to=iec "$ORIG_SIZE" 2>/dev/null || echo "$ORIG_SIZE") -> $(numfmt --to=iec "$NEW_SIZE" 2>/dev/null || echo "$NEW_SIZE") (Giảm ${SAVED_PERCENT}%)"
            TOTAL_ORIGINAL=$((TOTAL_ORIGINAL + ORIG_SIZE))
            TOTAL_COMPRESSED=$((TOTAL_COMPRESSED + NEW_SIZE))
        else
            echo "   ℹ️ File nén không nhỏ hơn file gốc, giữ nguyên file ban đầu."
            rm -f "$TMP_FILE"
            touch "${file}.done"
        fi
    else
        echo "   ⚠️ Nén thất bại, giữ nguyên file gốc."
        rm -f "$TMP_FILE"
    fi

done < <(find "$RECORD_DIR" -type f -name "*.mp4" -mmin +"$MIN_AGE_MINUTES")

echo "========================================================================"
if [ "$COUNT" -eq 0 ]; then
    echo "  ✨ Không có file nào cần nén."
else
    TOTAL_SAVED=$((TOTAL_ORIGINAL - TOTAL_COMPRESSED))
    echo "  🎉 HOÀN TẤT NÉN ${COUNT} FILE!"
    echo "  • Dung lượng gốc:     $(numfmt --to=iec "$TOTAL_ORIGINAL" 2>/dev/null || echo "$TOTAL_ORIGINAL bytes")"
    echo "  • Dung lượng sau nén: $(numfmt --to=iec "$TOTAL_COMPRESSED" 2>/dev/null || echo "$TOTAL_COMPRESSED bytes")"
    echo "  • Tiết kiệm được:     $(numfmt --to=iec "$TOTAL_SAVED" 2>/dev/null || echo "$TOTAL_SAVED bytes")"
fi
echo "========================================================================"
