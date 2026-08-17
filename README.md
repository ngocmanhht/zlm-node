# 🎥 ZLMediaKit Standalone Node (Host Network Mode)

Kho lưu trữ (Repo) độc lập này dùng để triển khai nhanh một **ZLMediaKit Media Node** trên bất kỳ máy chủ / VPS / VM nào bằng chế độ mạng trực tiếp **`--net=host`**, tự động đồng bộ cấu hình `config.ini` và kết nối về **WVP Master Server**.

---

## 📁 Cấu trúc thư mục

```text
zlm-node-standalone/
├── .env.example         # File mẫu cấu hình môi trường
├── .env                 # File cấu hình của Node này
├── config.template.ini  # Template cấu hình ZLMediaKit
├── docker-compose.yml   # Docker Compose chạy chế độ Host Network
├── deploy.sh            # Script 1-click tự sinh config và chạy Node
└── README.md            # Hướng dẫn sử dụng
```

---

## 🚀 Hướng dẫn cài đặt trên Server mới (Chỉ mất 1 phút)

### Bước 1: Copy / Git clone thư mục này về Server mới
```bash
git clone <URL_REPO_CUA_BAN> zlm-node
cd zlm-node
```

---

### Bước 2: Chỉnh sửa thông số trong file `.env`
Mở file `.env`:
```bash
nano .env
```
Điền các thông số cơ bản:
```properties
# 1. Tên định danh cho Node này (bắt buộc duy nhất, ví dụ: zlm_node_02, zlm_node_03,...)
MEDIA_SERVER_ID=zlm_node_02

# 2. Khóa Secret API (khớp với secret hệ thống WVP)
SECRET=su6TiedN2rVAmBbIDX0aa0QTiBJLBdcf

# 3. IP và Cổng của máy chủ WVP Master (để Node gửi webhook báo sự kiện về WVP)
WVP_HOST=192.168.100.1
WVP_PORT=18978

# 4. Thư mục lưu trữ video trên máy chủ này
VIDEO_STORAGE_PATH=/data/video
```

---

### Bước 3: Chạy script triển khai tự động
```bash
chmod +x deploy.sh
./deploy.sh
```

Script sẽ:
1. Đọc file `.env`.
2. Tự động sinh file `conf/config.ini` chuẩn xác với các đường dẫn Webhook trỏ về WVP Master.
3. Tạo thư mục lưu video `/data/video`.
4. Khởi chạy container ZLMediaKit với `--net=host`.

---

### Bước 4: Khai báo Node lên giao diện Web WVP Master

1. Truy cập Web WVP Master: `http://<IP_WVP_MASTER>:8080/#/mediaServer`.
2. Vào **Media node** $\rightarrow$ Bấm **Add node**.
3. Điền thông tin:
   - **IP**: Địa chỉ IP của Server mới này.
   - **HTTP port**: `80` (hoặc port bạn cấu hình trong `.env`).
   - **SECRET**: Khóa `SECRET` trong `.env`.
   - **Type**: `ZLMediaKit`.
4. Bấm **Test** $\rightarrow$ Hiện dấu tích xanh ✅ $\rightarrow$ Bấm **Next step** $\rightarrow$ Bấm **Save**.

Node mới sẽ ngay lập tức chuyển sang trạng thái **`Online`**!

---

## 🛠️ Các lệnh quản lý

* **Xem log hoạt động:**
  ```bash
  docker logs -f zlm_zlm_node_02
  ```
* **Khởi động lại Node:**
  ```bash
  ./deploy.sh
  ```
* **Dừng Node:**
  ```bash
  docker compose down
  ```
# zlm-node
