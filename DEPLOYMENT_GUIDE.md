# HƯỚNG DẪN TRIỂN KHAI & BÀN GIAO HỆ THỐNG MUSE RENTS

Tài liệu này cung cấp hướng dẫn chi tiết về cấu trúc dữ liệu, API, và các bước để triển khai (deploy) máy chủ (Server) cũng như cơ sở dữ liệu (Database) cho dự án Muse Rents. Tài liệu này dành cho lập trình viên hoặc người quản trị hệ thống tiếp quản dự án.

---

## 1. TỔNG QUAN HỆ THỐNG (ARCHITECTURE)

Hệ thống Muse Rents bao gồm 3 phần chính:
1. **Frontend (FE)**: Ứng dụng di động được xây dựng bằng Flutter (Hỗ trợ Android/iOS).
2. **Backend (BE)**: Máy chủ API được xây dựng bằng Node.js & Express.
3. **Database**: Cơ sở dữ liệu quan hệ MySQL, được cấu hình yêu cầu chứng chỉ SSL/TLS.

---

## 2. CẤU TRÚC THƯ MỤC CHÍNH

- `FE/`: Mã nguồn ứng dụng Flutter.
- `BE/`: Mã nguồn máy chủ Node.js.
- `database/`: Chứa các script SQL dùng để khởi tạo và cập nhật cơ sở dữ liệu.
  - `database_deploy.sql`: Script khởi tạo toàn bộ các bảng và dữ liệu mẫu.
  - `add_*.sql`: Các script cập nhật/migrate (dùng khi thêm tính năng mới).
- `MUSE_RENTS_PLAN.md`: Kế hoạch phát triển và theo dõi tiến độ dự án.

---

## 3. CƠ SỞ DỮ LIỆU (DATABASE) & AIVEN MYSQL

Hệ thống đang sử dụng **MySQL** và được khuyên dùng triển khai trên các nền tảng Cloud Database như **Aiven** (do có hỗ trợ chứng chỉ SSL `ca.pem` bảo mật tốt).

### 3.1. Các bước khởi tạo Database:
1. Tạo một MySQL Service trên Aiven (hoặc AWS RDS, DigitalOcean).
2. Tải tệp chứng chỉ **SSL Certificate (`ca.pem`)** từ nhà cung cấp Database.
3. Đặt tệp `ca.pem` vào thư mục `BE/config/` của mã nguồn Backend (Ghi đè file cũ nếu có).
4. Sử dụng công cụ như **DBeaver** hoặc **MySQL Workbench**, kết nối tới Database (nhớ cấu hình sử dụng SSL và nạp file `ca.pem`).
5. Mở và chạy file script `database/database_deploy.sql` để tạo toàn bộ các bảng.
6. (Tùy chọn) Chạy lần lượt các file `add_*.sql` nếu bảng chưa được cập nhật các tính năng mới nhất (như tính năng chat, xóa tin nhắn).

---

## 4. TRIỂN KHAI BACKEND (NODE.JS SERVER)

Backend có thể được triển khai trên các nền tảng như **Render.com**, **Railway**, hoặc VPS (Ubuntu/CentOS).

### 4.1. Cài đặt biến môi trường (Environment Variables)
Bạn cần tạo một file `.env` ở trong thư mục `BE/` (khi chạy local) hoặc thiết lập các Environment Variables trên Dashboard của Render.com với các thông tin sau:

```env
PORT=3000
DB_HOST=mysql-xxxx-aiven.aivencloud.com
DB_PORT=11893
DB_USER=avnadmin
DB_PASSWORD=your_database_password
DB_NAME=defaultdb
JWT_SECRET=your_jwt_secret_key_here
```
*(Thay thế các giá trị trên bằng thông tin thực tế từ Database của bạn)*

### 4.2. Cài đặt & Chạy Local
1. Mở terminal, di chuyển vào thư mục `BE/`:
   ```bash
   cd BE
   ```
2. Cài đặt các thư viện phụ thuộc:
   ```bash
   npm install
   ```
3. Khởi chạy Server:
   ```bash
   npm start
   # hoặc dùng nodemon để tự động reload khi code thay đổi: npm run dev
   ```

### 4.3. Triển khai lên Render.com (Production)
1. Kết nối Github repository của bạn với Render.
2. Tạo một **Web Service** mới.
3. Cấu hình:
   - Build Command: `npm install`
   - Start Command: `node server.js` (hoặc `npm start`)
   - Root Directory: `BE`
4. Thêm toàn bộ các biến môi trường (Environment Variables) ở mục 4.1 vào phần thiết lập của Render.
5. Triển khai (Deploy). Sau khi xong, Render sẽ cấp cho bạn một đường dẫn (VD: `https://muse-rents.onrender.com`).

---

## 5. TỔNG QUAN API

Các API chính được chia thành các nhóm Routes:

- **`/api/auth`**: Đăng nhập, đăng ký, thay đổi mật khẩu, lấy thông tin user hiện tại (`/me`).
- **`/api/users`**: Quản lý tài khoản (phân quyền, duyệt tài khoản pending, vô hiệu hóa).
- **`/api/classes`**: Quản lý lớp học (CRUD), chi tiết lớp, danh sách học viên trong lớp, thay đổi trạng thái (active, cancelled, completed).
- **`/api/classes/:id/messages`**: Quản lý tin nhắn Chat trong lớp (gửi, tải lịch sử, xóa, thả cảm xúc). Hỗ trợ upload tệp đính kèm (ảnh, doc, excel, pdf) thông qua `multer`.
- **`/api/enrollments`**: Đăng ký khóa học, cập nhật trạng thái thanh toán (đợt 1, đợt 2), và lưu nhận xét của giáo viên/học viên.
- **`/api/notifications`**: Hệ thống thông báo tự động (cảnh báo học phí, thông báo lớp mới, v.v.).

*Lưu ý bảo mật*: Hầu hết các API đều được bảo vệ bởi middleware `auth`. Cần truyền token ở header: `Authorization: Bearer <token>`.

---

## 6. CẤU HÌNH FRONTEND (FLUTTER APP)

Khi đổi Server (hoặc cấu hình lại URL), cần phải báo cho ứng dụng di động biết địa chỉ Backend mới.

1. Mở file `FE/lib/services/api_service.dart`.
2. Sửa hằng số `serverUrl` thành địa chỉ Backend của bạn.
   ```dart
   // Ví dụ cho Local:
   // static const String serverUrl = 'http://192.168.1.100:3000';
   
   // Ví dụ cho Production (Render):
   static const String serverUrl = 'https://muse-rents.onrender.com';
   ```
3. Lưu ý thêm: Ở môi trường Local, hãy dùng địa chỉ IP IPv4 của máy tính mạng LAN (VD: `192.168.x.x`), tuyệt đối không dùng `localhost` hay `127.0.0.1` vì máy ảo/thiết bị thật sẽ không hiểu.

### Đóng gói Ứng dụng (Build APK)
Để build bản cài đặt cho Android, hãy chạy lệnh sau trong thư mục `FE/`:
```bash
flutter build apk --release
```
File APK sẽ xuất hiện tại `FE/build/app/outputs/flutter-apk/app-release.apk`.
