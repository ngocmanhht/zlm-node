# HƯỚNG DẪN TRIỂN KHAI ZLMEDIKIT WORKER NODE (CLUSTER JOIN TOKEN)

Thư mục này chứa toàn bộ cấu hình để triển khai **ZLMediaKit ở chế độ phân tán (Standalone Worker Node)** theo chuẩn **Cluster Join Token** (tương tự cơ chế `kubeadm join --token` của Kubernetes).

### 🛡️ ƯU ĐIỂM BẢO MẬT VƯỢT TRỘI:
1. **Hoàn toàn KHÔNG lộ Username / Password Quản trị viên**: File `.env` và máy chủ Worker tuyệt đối không chứa thông tin đăng nhập của WVP Master.
2. **Bảo mật chia vùng (Partitioned Security)**: Mỗi Node Worker sở hữu một `NODE_SECRET` độc lập cho riêng mình.
3. **Zero-touch Auto Enrollment**: Khi ZLMediaKit khởi động, nó tự động gửi thông tin gia nhập kèm mã Token. WVP Master tự phê duyệt và chuyển node sang **🟢 ONLINE** ngay lập tức mà không cần chạy bất kỳ script phụ nào.

---

## 🏗️ KIẾN TRÚC HOẠT ĐỘNG

```
     [ ZLMediaKit Worker Node ]                     [ WVP Master Control Plane ]
                 │                                               │
(1) Khởi động container ZLMediaKit                               │
                 │                                               │
(2) Gửi Webhook on_server_started?secret=<CLUSTER_JOIN_TOKEN>   │
    Kèm thông tin: NODE_ID, NODE_SECRET, sdp_ip, stream_ip...    │
                 ───────────────────────────────────────────────>│
                                                                 │
                                                    (3) Kiểm tra CLUSTER_JOIN_TOKEN:
                                                        - Nếu đúng: Tự động lưu Node
                                                          vào CSDL & Cache
                                                        - Kích hoạt trạng thái ONLINE!
                 │<──────────────────────────────────────────────│
                 │
(4) Nhịp tim keepalive & sẵn sàng nhận luồng Camera!
```

## 🔑 HỖ TRỢ MULTI CLUSTER_JOIN_TOKEN (PHÂN TÁCH VÙNG & XOAY VÒNG TOKEN)

Hệ thống hỗ trợ cấu hình **Nhiều Token Gia Nhập (Multi-Token)** cùng lúc trên WVP Master, phân tách bằng dấu phẩy `,`:
```yaml
# Cấu hình trên WVP Master (biến môi trường MEDIA_SECRET):
MEDIA_SECRET: "token_north_2026,token_south_2026,token_danang_2026,token_edge_backup"
```

* **Lợi ích 1: Phân tách quyền từng vùng:**
  * Node Miền Bắc dùng: `CLUSTER_JOIN_TOKEN=token_north_2026`
  * Node Miền Nam dùng: `CLUSTER_JOIN_TOKEN=token_south_2026`
  * Nếu Node Miền Bắc bị lộ token, anh chỉ cần xóa `token_north_2026` trên Master mà **không làm ảnh hưởng đến các Node Miền Nam**.
* **Lợi ích 2: Xoay vòng Token không gián đoạn (Zero-Downtime Rotation):**
  * Thêm Token mới vào danh sách trên Master (`token_cu,token_moi`).
  * Cập nhật các Node sang Token mới rồi xóa Token cũ đi mà hệ thống không bao giờ phải dừng.

---

## 🚀 CÁC BƯỚC TRIỂN KHAI WORKER NODE MỚI

### Bước 1: Copy thư mục `zlm-node` sang máy chủ Worker
Copy toàn bộ thư mục này sang máy chủ bạn muốn làm Media Node.

### Bước 2: Cấu hình thông số Node trong `.env`
Tạo file `.env` từ file mẫu:
```bash
cp .env.example .env
```

Mở file `.env` và điền thông số của vùng đó:
```ini
# 1. Trỏ về WVP Master
WVP_MASTER_HOST=192.168.1.100
WVP_MASTER_PORT=18978

# Token gia nhập cụm (Phải khớp với "media.secret" trên WVP Master)
CLUSTER_JOIN_TOKEN=wvp_cluster_join_secret_key_2026

# 2. Định danh và Secret riêng biệt của Node này (Bảo mật chia vùng)
NODE_ID=zlm_north_01
NODE_SECRET=secret_rieng_mien_bac_9988

# 3. Địa chỉ IP máy chủ này
NODE_IP=192.168.1.101          # IP nội bộ kết nối Master
NODE_SDP_IP=192.168.1.101       # IP để Camera nhìn thấy và bắn RTP vào (hoặc WAN IP)
NODE_STREAM_IP=192.168.1.101    # IP để Client Web/App kết nối vào xem (hoặc WAN IP)
```

### Bước 3: Khởi động 1-Click
Chạy lệnh khởi động:
```bash
./start.sh
```
*(Hoặc: `bash generate-config.sh && docker compose up -d`)*

---

## 🎯 KẾT QUẢ:
* Ngay sau khi container ZLMediaKit chạy, đăng nhập vào trang Web WVP Master (`http://<IP_WVP>:18978`) ➔ Menu **`Quản lý Node (Node Management)`**.
* Node `zlm_north_01` sẽ tự động hiển thị với trạng thái **🟢 ONLINE** kèm đầy đủ địa chỉ IP và Secret độc lập của riêng node đó!

---

## 🗜️ TỐI ƯU HÓA DUNG LƯỢNG LƯU TRỮ (REDUCE STORAGE)
ZLMediaKit mặc định đóng gói trực tiếp luồng RTP thành MP4 (không transcode on-the-fly để bảo toàn CPU). Để giảm dung lượng lưu trữ:

### 1. Tự động nén & Resize MP4 Offline (`compress-records.sh`):
Chạy script nén các file MP4 đã ghi bằng FFmpeg (chuẩn H.265/HEVC, resize về tối đa 720p):
```bash
./compress-records.sh
```
*Tùy chọn lập lịch chạy tự động ban đêm (Cronjob):*
```bash
# Chạy lúc 2h sáng mỗi ngày
0 2 * * * cd /path/to/zlm-node && ./compress-records.sh >> /var/log/zlm_compress.log 2>&1
```

### 2. Tự động xóa file cũ theo số ngày (`RECORD_DAY`):
Cấu hình trong `.env`:
```ini
RECORD_DAY=7   # Tự động xóa các video cũ hơn 7 ngày (WVP Master chạy dọn dẹp lúc 0h)
```

