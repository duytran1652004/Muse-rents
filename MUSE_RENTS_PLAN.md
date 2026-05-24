# MUSE RENTS - Kế Hoạch Thiết Kế Ứng Dụng

## 📋 Tổng Quan Dự Án
**MUSE Rents** là ứng dụng quản lý cho thuê phòng tập/studio và quản lý học viên. Ứng dụng hỗ trợ:
- Quản lý phòng/studio
- Quản lý học viên & đăng ký lớp
- Quản lý booking (đặt phòng)
- Quản lý thanh toán/hóa đơn
- Báo cáo thống kê
- Hệ thống thông báo

---

## 🎨 Giao Diện & Màu Sắc (Blue-White Theme)

### Bảng Màu (Dựa trên Logo MUSE - Xanh-Trắng)
```
Primary Color (Blue):
  - primaryBlue = Color(0xFF4000FF)     // Xanh dương chính
  - primaryBlueDark = Color(0xFF2D00CC) // Xanh dương tối
  - primaryBlueLight = Color(0xFF6B42FF) // Xanh dương nhạt

Neutral Colors:
  - white = Color(0xFFFFFFFF)           // Trắng
  - grayLight = Color(0xFFF5F5F5)       // Xám nhạt
  - grayMedium = Color(0xFFE0E0E0)      // Xám trung bình
  - grayDark = Color(0xFF666666)        // Xám tối
  - black = Color(0xFF333333)           // Đen (chữ)

Accent Colors:
  - accentGreen = Color(0xFF4CAF50)     // Xanh lá (success)
  - accentOrange = Color(0xFFFF9800)    // Cam (warning)
  - accentRed = Color(0xFFF44336)       // Đỏ (error)

Background:
  - bgWhite = Color(0xFFFFFFFF)         // Nền trắng
  - bgGray = Color(0xFFF9F9F9)          // Nền xám nhạt
  - bgCard = Color(0xFFFAFAFA)          // Card background
```

### Main Gradient
```
LinearGradient: White → Blue gradient for headers
```

### Theme Style
- **Light Theme**: Nền trắng/xám, chữ đen - Clean & Professional
- **Blue Accent**: Gradient blue cho header, buttons, icons
- **White Cards**: Card trắng với border/shadow xanh nhạt
- **Border Radius**: 12-16dp cho cards, buttons

---

## 📁 Cấu Trúc Thư Mục

```
Muse/
├── MUSE Event/                    (Tham khảo - không sửa)
│   ├── BE/
│   ├── FE/
│   └── init_db.sql
│
└── Muse Rents/                     (PROJECT MỚI)
    ├── BE/
    │   ├── config/
    │   │   └── db.js
    │   ├── controllers/
    │   │   ├── authController.js
    │   │   ├── roomController.js
    │   │   ├── studentController.js
    │   │   ├── bookingController.js
    │   │   ├── notificationController.js
    │   │   └── reportController.js
    │   ├── routes/
    │   │   ├── authRoutes.js
    │   │   ├── roomRoutes.js
    │   │   ├── studentRoutes.js
    │   │   ├── bookingRoutes.js
    │   │   ├── notificationRoutes.js
    │   │   └── reportRoutes.js
    │   ├── middleware/
    │   │   └── auth.js
    │   ├── uploads/
    │   ├── server.js
    │   ├── package.json
    │   ├── .env
    │   ├── .gitignore
    │   └── init_db.sql
    │
    ├── FE/                         (Flutter Project)
    │   ├── lib/
    │   │   ├── main.dart
    │   │   ├── screens/
    │   │   │   ├── auth/
    │   │   │   │   ├── login_screen.dart
    │   │   │   │   └── register_screen.dart
    │   │   │   ├── admin/
    │   │   │   │   ├── admin_home_screen.dart
    │   │   │   │   ├── room_management_screen.dart
    │   │   │   │   ├── student_management_screen.dart
    │   │   │   │   ├── booking_management_screen.dart
    │   │   │   │   ├── create_room_screen.dart
    │   │   │   │   └── reports_screen.dart
    │   │   │   ├── user/
    │   │   │   │   ├── user_home_screen.dart
    │   │   │   │   ├── room_listing_screen.dart
    │   │   │   │   ├── booking_screen.dart
    │   │   │   │   ├── my_bookings_screen.dart
    │   │   │   │   └── profile_screen.dart
    │   │   │   ├── shared/
    │   │   │   │   ├── room_detail_screen.dart
    │   │   │   │   ├── notification_screen.dart
    │   │   │   │   └── history_screen.dart
    │   │   ├── widgets/
    │   │   │   ├── room_card.dart
    │   │   │   ├── booking_item.dart
    │   │   │   ├── top_notification_banner.dart
    │   │   │   └── gradient_button.dart
    │   │   ├── theme/
    │   │   │   └── rents_colors.dart
    │   │   ├── models/
    │   │   │   ├── user.dart
    │   │   │   ├── room.dart
    │   │   │   ├── student.dart
    │   │   │   ├── booking.dart
    │   │   │   └── payment.dart
    │   │   ├── services/
    │   │   │   └── api_service.dart
    │   │   └── utils/
    │   │       └── constants.dart
    │   ├── assets/
    │   │   ├── images/
    │   │   │   ├── logo.png
    │   │   │   ├── icon_bg.png
    │   │   │   └── icon_foreground.png
    │   │   └── fonts/
    │   ├── pubspec.yaml
    │   ├── .gitignore
    │   └── (Flutter default folders: android, ios, linux, macos, web, windows)
    │
    └── README.md
```

---

## 🗄️ Database Schema

### Users Table
```sql
users(
  id INT PRIMARY KEY,
  full_name VARCHAR(100),
  phone_number VARCHAR(20) UNIQUE,
  email VARCHAR(100) UNIQUE,
  password_hash VARCHAR(255),
  role ENUM('admin', 'staff', 'student'),
  active BOOLEAN,
  created_at TIMESTAMP
)
```

### Rooms/Studios Table
```sql
rooms(
  id INT PRIMARY KEY,
  name VARCHAR(100),
  description TEXT,
  capacity INT,
  price_per_hour DECIMAL,
  facilities TEXT,        -- e.g., "Mirrors, Sound System, AC"
  status ENUM('active', 'maintenance', 'closed'),
  created_at TIMESTAMP
)
```

### Students Table
```sql
students(
  id INT PRIMARY KEY,
  user_id INT FOREIGN KEY,
  name VARCHAR(100),
  phone VARCHAR(20),
  email VARCHAR(100),
  address VARCHAR(255),
  enrollment_date DATE,
  status ENUM('active', 'inactive', 'suspended'),
  created_at TIMESTAMP
)
```

### Bookings Table
```sql
bookings(
  id INT PRIMARY KEY,
  student_id INT FOREIGN KEY,
  room_id INT FOREIGN KEY,
  booking_date DATE,
  start_time TIME,
  end_time TIME,
  duration_hours INT,
  price DECIMAL,
  status ENUM('pending', 'confirmed', 'completed', 'cancelled'),
  notes TEXT,
  created_at TIMESTAMP
)
```

### Payments Table
```
❌ REMOVED - Ứng dụng nội bộ, không xử lý thanh toán
```

### Notifications Table
```sql
classes(
  id INT PRIMARY KEY,
  room_id INT FOREIGN KEY,
  instructor_id INT FOREIGN KEY,
  class_name VARCHAR(100),
  day_of_week ENUM('Monday', 'Tuesday', ...),
  start_time TIME,
  end_time TIME,
  max_students INT,
  price_per_class DECIMAL,
  status ENUM('active', 'cancelled')
)
```

### Class Enrollments Table
```sql
class_enrollments(
  id INT PRIMARY KEY,
  class_id INT FOREIGN KEY,
  student_id INT FOREIGN KEY,
  enrollment_date DATE,
  status ENUM('active', 'completed', 'dropped'),
  created_at TIMESTAMP
)
```

### Notifications Table
```sql
notifications(
  id INT PRIMARY KEY,
  user_id INT FOREIGN KEY,
  type ENUM('booking', 'payment', 'class', 'alert'),
  title VARCHAR(200),
  message TEXT,
  is_read BOOLEAN,
  created_at TIMESTAMP
)
```

---

## 🔄 Workflow & Features

### Admin Features
1. **Quản lý phòng/studio**
   - CRUD phòng
   - Thiết lập giá thuê
   - Quản lý trạng thái (active, maintenance, closed)

2. **Quản lý học viên**
   - Thêm/sửa/xóa học viên
   - Xem danh sách học viên
   - Quản lý kiểm tra, tạm dừng

3. **Quản lý booking**
   - Xem tất cả booking
   - Xác nhận/hủy booking
   - Quản lý lịch phòng

4. **Quản lý lớp học**
   - Tạo lớp học định kỳ
   - Quản lý học viên đăng ký lớp
   - Xem lịch lớp

5. **Quản lý thanh toán**
   - Xem danh sách thanh toán
   - Xác nhận thanh toán
   - Tạo hóa đơn

6. **Báo cáo & Thống kê**
   - Doanh thu theo tháng
   - Số buổi đặt phòng
   - Tỷ lệ sử dụng phòng
   - Danh sách học viên hợp tác

### Student/User Features
1. **Xem danh sách phòng**
   - Tìm kiếm phòng
   - Xem chi tiết giá, tiện ích
   - Xem lịch trống

2. **Đặt phòng**
   - Chọn ngày, giờ
   - Xác nhận thông tin
   - Lưu booking

3. **Quản lý booking của tôi**
   - Xem danh sách booking
   - Hủy booking (nếu còn thời gian)
   - Xem lịch sử

4. **Thanh toán**
   - Xem hóa đơn chưa thanh toán
   - Thanh toán online/offline
   - Xem lịch sử thanh toán

5. **Đăng ký lớp học**
   - Xem danh sách lớp
   - Đăng ký lớp
   - Quản lý lớp của tôi

6. **Hồ sơ & Thông báo**
   - Cập nhật thông tin cá nhân
   - Xem thông báo

---

## 🎯 Backend Endpoints (API)

### Authentication
- `POST /api/auth/register` - Đăng ký
- `POST /api/auth/login` - Đăng nhập
- `POST /api/auth/logout` - Đăng xuất
- `GET /api/auth/verify` - Kiểm tra token

### Rooms
- `GET /api/rooms` - Danh sách phòng
- `GET /api/rooms/:id` - Chi tiết phòng
- `POST /api/rooms` - Tạo phòng (admin)
- `PUT /api/rooms/:id` - Cập nhật phòng (admin)
- `DELETE /api/rooms/:id` - Xóa phòng (admin)

### Students
- `GET /api/students` - Danh sách học viên (admin)
- `GET /api/students/:id` - Chi tiết học viên
- `POST /api/students` - Tạo học viên
- `PUT /api/students/:id` - Cập nhật học viên
- `DELETE /api/students/:id` - Xóa học viên (admin)

### Bookings
- `GET /api/bookings` - Danh sách booking
- `GET /api/bookings/available` - Xem giờ trống
- `POST /api/bookings` - Tạo booking mới
- `PUT /api/bookings/:id` - Cập nhật booking
- `DELETE /api/bookings/:id` - Hủy booking
- `GET /api/bookings/history` - Lịch sử booking

### Payments
- `GET /api/payments` - Danh sách thanh toán
- `POST /api/payments` - Tạo thanh toán
- `PUT /api/payments/:id/confirm` - Xác nhận thanh toán
- `GET /api/payments/invoices/:id` - Lấy hóa đơn

### Classes
- `GET /api/classes` - Danh sách lớp
- `POST /api/classes` - Tạo lớp (admin)
- `POST /api/classes/:id/enroll` - Đăng ký lớp
- `DELETE /api/classes/:id/unenroll` - Hủy đăng ký lớp

### Notifications
- `GET /api/notifications` - Danh sách thông báo
- `PUT /api/notifications/:id/read` - Đánh dấu đã đọc

### Reports
- `GET /api/reports/revenue` - Thống kê doanh thu
- `GET /api/reports/bookings` - Thống kê booking
- `GET /api/reports/rooms-usage` - Sử dụng phòng

---

## 📱 Frontend Screens

### Auth Screens
- **LoginScreen** - Đăng nhập với số điện thoại/email
- **RegisterScreen** - Đăng ký học viên mới

### Admin Screens
- **AdminHomeScreen** - Dashboard với thống kê nhanh
- **RoomManagementScreen** - CRUD phòng
- **CreateRoomScreen** - Tạo phòng mới
- **StudentManagementScreen** - Quản lý học viên
- **BookingManagementScreen** - Quản lý booking
- **PaymentTrackingScreen** - Xem thanh toán
- **ReportsScreen** - Báo cáo & thống kê

### User/Student Screens
- **UserHomeScreen** - Dashboard học viên
- **RoomListingScreen** - Danh sách phòng
- **RoomDetailScreen** - Chi tiết phòng
- **BookingScreen** - Đặt phòng mới
- **MyBookingsScreen** - Booking của tôi
- **PaymentScreen** - Thanh toán
- **ProfileScreen** - Thông tin cá nhân

### Shared Screens
- **NotificationScreen** - Thông báo
- **HistoryScreen** - Lịch sử

---

## 🛠️ Tech Stack

### Backend
- **Runtime**: Node.js
- **Framework**: Express.js
- **Database**: MySQL
- **Authentication**: JWT
- **File Upload**: Multer
- **Other**: CORS, Dotenv

### Frontend
- **Framework**: Flutter (Dart)
- **HTTP**: http package
- **Storage**: shared_preferences
- **Image Picker**: image_picker
- **Theme**: Custom colors + Gradients
- **Icons**: Material Icons

---

## 📋 Implementation Phases

### Phase 1: Backend Setup
1. Initialize Node.js project
2. Setup database schema
3. Create authentication API
4. Create basic CRUD endpoints (rooms, students)

### Phase 2: Core Features Backend
1. Booking management API
2. Payment system API
3. Notification system
4. Reports API

### Phase 3: Frontend Setup & Auth
1. Initialize Flutter project
2. Setup theme and colors
3. Login/Register screens
4. Local storage for auth tokens

### Phase 4: Admin Features Frontend
1. Dashboard
2. Room management UI
3. Student management UI
4. Reports UI

### Phase 5: User Features Frontend
1. Room listing & search
2. Booking UI
3. Payment UI
4. Profile & Settings

### Phase 6: Polish & Deployment
1. Testing
2. Performance optimization
3. UI/UX refinement
4. Deployment setup

---

## 📝 Notes
- Use dark theme giống MUSE Event
- Gradient blue-pink giống logo MUSE
- Reuse color palette từ muse_colors.dart
- API endpoint naming convention giống MUSE Event
- Database structure tương tự MUSE Event (users, roles, created_at...)

---

**Status**: ⏳ Awaiting approval before implementation
