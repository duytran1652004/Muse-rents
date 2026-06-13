-- MySQL / MariaDB SQL Dump cho việc Deploy lên Cloud Server
-- Đã tích hợp trực tiếp PRIMARY KEY và AUTO_INCREMENT vào CREATE TABLE để tránh lỗi trên các Cloud Database khắt khe.

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET NAMES utf8mb4 */;

-- Tắt kiểm tra khóa ngoại trong lúc tạo bảng để tránh lỗi thứ tự
SET FOREIGN_KEY_CHECKS = 0;

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `users`
-- --------------------------------------------------------
CREATE TABLE `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `full_name` varchar(100) NOT NULL,
  `phone_number` varchar(20) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('admin','staff','teacher') DEFAULT 'staff',
  `active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `avatar_image` varchar(255) DEFAULT NULL,
  `cover_image` varchar(255) DEFAULT NULL,
  `session_token` varchar(500) DEFAULT NULL,
  UNIQUE KEY `phone_number` (`phone_number`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `users` (`id`, `full_name`, `phone_number`, `email`, `password_hash`, `role`, `active`, `created_at`, `avatar_image`, `cover_image`) VALUES
(1, 'Admin Muse', '0123456789', 'admin', '$2a$10$fcjqOGV9WEX5taqDVN0OYuO.QPfWHG7xi9xh43AeDFTBOv2NHAOO.', 'admin', 1, '2026-05-12 05:00:08', NULL, NULL),
(6, 'DJ ENER', '09123712123', 'teacher', '$2a$10$UBvFqfELgKLbmT3QDUSW3umXJgMF.ZvoUpoR1qrAq7md9d2vbrzBm', 'teacher', 1, '2026-06-04 07:39:57', NULL, NULL),
(7, 'Lam', '123021123', 'staff', '$2a$10$dHTdw2mAZquyilKDlKUlQeIpnFOZ2JG/y0mYfU8HOhBcKkI4wGH0q', 'staff', 1, '2026-06-04 07:43:33', NULL, NULL);

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `students`
-- --------------------------------------------------------
CREATE TABLE `students` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` int(11) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `enrollment_date` date DEFAULT NULL,
  `status` enum('confirmed','active','inactive','suspended') DEFAULT 'confirmed',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `user_id` (`user_id`),
  CONSTRAINT `students_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `students` (`id`, `user_id`, `name`, `phone`, `email`, `address`, `enrollment_date`, `status`, `created_at`) VALUES
(1, NULL, 'Nipun Patnaik', '09818251489', 'nipunpatnaik@gmail.com', '', '2026-05-16', 'active', '2026-05-16 05:12:00'),
(2, NULL, 'Hạ Chiêu', '0937836892', 'hacheew.ieg@gmail.com', '', '2026-05-16', 'active', '2026-05-16 05:12:00'),
(3, NULL, 'Minh Anh', '0778717859', 'minhanhjulie@gmail.com', '', '2026-05-16', 'confirmed', '2026-05-16 05:12:00'),
(4, NULL, 'Vũ Thị Hải', '0364660082', 'miyukihachi2k3@gmail.com', '', '2026-05-16', 'active', '2026-05-16 05:12:00'),
(5, NULL, 'Toney', '0886234725', 'Nhuphuongtoantran@gmail.com', '', '2026-05-16', 'confirmed', '2026-05-16 05:12:00');

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `rooms`
-- --------------------------------------------------------
CREATE TABLE `rooms` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `capacity` int(11) DEFAULT 0,
  `price_per_hour` decimal(10,2) NOT NULL,
  `facilities` text DEFAULT NULL,
  `status` enum('active','maintenance','closed') DEFAULT 'active',
  `image_url` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `rooms` (`id`, `name`, `description`, `capacity`, `price_per_hour`, `facilities`, `status`, `image_url`, `created_at`) VALUES
(5, 'XDJ - AZ', 'Thuê phòng tập DJ: XDJ - AZ', 2, 300000.00, 'XDJ - AZ', 'active', '/uploads/1779519160172-409214528.png', '2026-05-14 07:51:20'),
(6, 'XDJ - XZ', 'Thuê phòng tập DJ: XDJ - XZ', 2, 200000.00, 'XDJ - XZ', 'active', '/uploads/1779515059629-28177657.png', '2026-05-14 07:51:20'),
(7, 'XDJ - RX3', 'Thuê phòng tập DJ: XDJ - RX3', 2, 200000.00, 'XDJ - RX3', 'active', '/uploads/1779515113262-241170630.png', '2026-05-14 07:51:20'),
(8, 'XDJ - RR', 'Thuê phòng tập DJ: XDJ - RR', 2, 170000.00, 'XDJ - RR', 'active', '/uploads/1779515101135-852767523.png', '2026-05-14 07:51:20'),
(10, 'Half Set CDJ 2000 NXS2 - 900 NXS2', 'Thuê phòng tập DJ: Half Set CDJ 2000 NXS2 và Mixer 900 NXS2', 4, 350000.00, 'CDJ 2000 NXS2, Mixer 900 NXS2', 'active', '/uploads/1779519320186-52675513.png', '2026-05-16 05:12:00'),
(11, 'Half Set CDJ 3000 - DJM A9', 'Thuê phòng tập DJ: Half Set CDJ 3000 và Mixer DJM - A9', 4, 450000.00, 'CDJ 3000, Mixer DJM - A9', 'active', '/uploads/1779519271630-969196125.png', '2026-05-16 05:12:00'),
(12, 'Turntable PLX 1000 - DJM S7', 'Thuê phòng tập DJ: Turntable PLX - 1000 và Mixer DJM S7', 4, 350000.00, 'Turntable PLX 1000, Mixer DJM S7', 'active', '/uploads/1779515658930-482077040.png', '2026-05-16 05:12:00');

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `bookings`
-- --------------------------------------------------------
CREATE TABLE `bookings` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `student_id` int(11) DEFAULT NULL,
  `room_id` int(11) DEFAULT NULL,
  `booking_date` date NOT NULL,
  `start_time` time NOT NULL,
  `end_time` time NOT NULL,
  `duration_hours` int(11) DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `status` enum('pending','confirmed','in_progress','completed','cancelled') DEFAULT 'pending',
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `created_by` int(11) DEFAULT NULL,
  KEY `student_id` (`student_id`),
  KEY `room_id` (`room_id`),
  KEY `fk_bookings_created_by` (`created_by`),
  CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`),
  CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`id`),
  CONSTRAINT `fk_bookings_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `bookings` (`id`, `student_id`, `room_id`, `booking_date`, `start_time`, `end_time`, `duration_hours`, `price`, `status`, `notes`, `created_at`, `created_by`) VALUES
(10, NULL, 6, '2026-05-23', '13:30:00', '14:30:00', NULL, 200000.00, 'completed', '{\"note\":\"\",\"customerType\":\"guest\",\"guestName\":\"Tommy\",\"guestPhone\":\"\",\"discountType\":\"percent\",\"discountValue\":0,\"discountAmount\":0,\"basePrice\":200000,\"finalPrice\":200000}', '2026-05-23 06:38:46', 1),
(12, NULL, 6, '2026-05-23', '16:00:00', '17:00:00', NULL, 200000.00, 'completed', '{\"note\":\"\",\"customerType\":\"guest\",\"guestName\":\"Leon\",\"guestPhone\":\"\",\"discountType\":\"percent\",\"discountValue\":0,\"discountAmount\":0,\"basePrice\":200000,\"finalPrice\":200000}', '2026-05-23 09:04:21', 1),
(15, NULL, 11, '2026-05-29', '13:15:00', '14:15:00', NULL, 450000.00, 'completed', '{\"note\":\"\",\"customerType\":\"guest\",\"guestName\":\"Spence\",\"guestPhone\":\"\",\"discountType\":\"percent\",\"discountValue\":0,\"discountAmount\":0,\"basePrice\":450000,\"finalPrice\":450000}', '2026-05-29 06:16:21', 1);

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `courses`
-- --------------------------------------------------------
CREATE TABLE `courses` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(255) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `duration` varchar(100) DEFAULT NULL,
  `status` enum('active','closed') DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `image_url` varchar(500) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `courses` (`id`, `name`, `description`, `price`, `duration`, `status`, `created_at`, `image_url`) VALUES
(1, 'KHÓA HỌC DJ CHUYÊN NGHIỆP', 'Professional DJ Course', 38000000.00, '33', 'active', '2026-05-14 07:51:20', '/uploads/1779348308944-631003393.jpg'),
(2, 'KHÓA HỌC DJ DÀNH CHO TRẺ EM', 'DJ Kids Course', 7000000.00, '8', 'active', '2026-05-14 07:51:20', '/uploads/1779348318233-41801981.jpg'),
(3, 'KHÓA HỌC DJ CƠ BẢN', 'Basic DJ Course', 9500000.00, '8', 'active', '2026-05-14 07:51:20', '/uploads/1779348328873-620778466.jpg'),
(4, 'KHÓA HỌC DJ TRUNG CẤP', 'Intermediate DJ Course', 17000000.00, '14', 'active', '2026-05-14 07:51:20', '/uploads/1779348341997-26458332.jpg'),
(5, 'KHÓA HỌC DJ NÂNG CAO', 'Advanced DJ Course', 17000000.00, '12', 'active', '2026-05-14 07:51:20', '/uploads/1779348353293-930036361.jpg'),
(6, 'KHÓA HỌC DJ INFLUENCER', 'Influencer DJ Course', 8000000.00, '8', 'active', '2026-05-14 07:51:20', '/uploads/1779348379025-568324980.jpg'),
(7, 'KHÓA DJ AFTER HOURS', 'After Hours DJ Course', 5000000.00, '5', 'active', '2026-05-14 07:51:20', '/uploads/1779348389331-885625436.jpg'),
(8, 'KHÓA HỌC DJ CHUYÊN SÂU DÒNG NHẠC TECHNO', 'Techno Music DJ Course', 27000000.00, '29', 'active', '2026-05-14 07:51:20', '/uploads/1779348400981-315856592.jpg'),
(9, 'KHÓA HỌC URBAN DJ', 'Urban DJ Course', 29000000.00, '28', 'active', '2026-05-14 07:51:20', '/uploads/1779348410412-253493541.jpg'),
(10, 'KHÓA HỌC DJ CHUYÊN SÂU DÒNG NHẠC EDM', 'EDM DJ Course', 27000000.00, '23', 'active', '2026-05-14 07:51:20', '/uploads/1779348421743-615975923.jpg');

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `instructors`
-- --------------------------------------------------------
CREATE TABLE `instructors` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` varchar(100) NOT NULL,
  `phone` varchar(20) NOT NULL,
  `email` varchar(100) DEFAULT NULL,
  `bio` text DEFAULT NULL,
  `status` enum('active','inactive') DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `user_id` int(11) DEFAULT NULL,
  KEY `fk_instructor_user` (`user_id`),
  CONSTRAINT `fk_instructor_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `instructors` (`id`, `name`, `phone`, `email`, `bio`, `status`, `created_at`, `user_id`) VALUES
(4, 'DJ ENER', '09123712123', 'teacher', NULL, 'active', '2026-06-04 07:39:57', 6);

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `classes`
-- --------------------------------------------------------
CREATE TABLE `classes` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `course_id` int(11) DEFAULT NULL,
  `room_id` int(11) DEFAULT NULL,
  `instructor_id` int(11) DEFAULT NULL,
  `class_name` varchar(100) NOT NULL,
  `day_of_week` varchar(100) DEFAULT NULL,
  `start_time` time DEFAULT NULL,
  `end_time` time DEFAULT NULL,
  `max_students` int(11) DEFAULT NULL,
  `price_per_class` decimal(10,2) DEFAULT NULL,
  `status` enum('active','cancelled') DEFAULT 'active',
  `day_of_week_2` varchar(100) DEFAULT NULL,
  `start_time_2` time DEFAULT NULL,
  `end_time_2` time DEFAULT NULL,
  `day_of_week_3` varchar(100) DEFAULT NULL,
  `start_time_3` time DEFAULT NULL,
  `end_time_3` time DEFAULT NULL,
  `total_sessions` int(11) DEFAULT 0,
  `completed_sessions` int(11) DEFAULT 0,
  `created_by` int(11) DEFAULT NULL,
  KEY `room_id` (`room_id`),
  KEY `fk_course` (`course_id`),
  KEY `fk_instructor` (`instructor_id`),
  CONSTRAINT `classes_ibfk_1` FOREIGN KEY (`room_id`) REFERENCES `rooms` (`id`),
  CONSTRAINT `fk_course` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_instructor` FOREIGN KEY (`instructor_id`) REFERENCES `instructors` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `classes` (`id`, `course_id`, `room_id`, `instructor_id`, `class_name`, `day_of_week`, `start_time`, `end_time`, `max_students`, `price_per_class`, `status`, `day_of_week_2`, `start_time_2`, `end_time_2`, `day_of_week_3`, `start_time_3`, `end_time_3`, `total_sessions`, `completed_sessions`, `created_by`) VALUES
(6, 4, 10, 4, 'KHÓA HỌC DJ TRUNG CẤP', 'Wednesday', '15:00:00', '16:00:00', 4, 17000000.00, 'active', 'Friday', '15:00:00', '16:00:00', NULL, NULL, NULL, 14, 2, 1);

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `class_enrollments`
-- --------------------------------------------------------
CREATE TABLE `class_enrollments` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `class_id` int(11) DEFAULT NULL,
  `course_id` int(11) DEFAULT NULL,
  `student_id` int(11) DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `enrollment_date` date DEFAULT NULL,
  `status` enum('confirmed','active','completed','dropped') DEFAULT 'confirmed',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `created_by` int(11) DEFAULT NULL,
  KEY `class_id` (`class_id`),
  KEY `student_id` (`student_id`),
  KEY `course_id` (`course_id`),
  KEY `fk_class_enrollments_created_by` (`created_by`),
  CONSTRAINT `class_enrollments_ibfk_1` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`),
  CONSTRAINT `class_enrollments_ibfk_2` FOREIGN KEY (`student_id`) REFERENCES `students` (`id`),
  CONSTRAINT `class_enrollments_ibfk_3` FOREIGN KEY (`course_id`) REFERENCES `courses` (`id`),
  CONSTRAINT `fk_class_enrollments_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `class_enrollments` (`id`, `class_id`, `course_id`, `student_id`, `start_date`, `end_date`, `enrollment_date`, `status`, `created_at`, `created_by`) VALUES
(2, NULL, 5, 2, '2026-05-16', '2026-06-16', '2026-05-16', 'completed', '2026-05-16 09:09:33', 1),
(15, NULL, 1, 1, '2026-05-21', '2026-06-21', '2026-05-21', 'completed', '2026-05-21 09:29:47', 1),
(21, 6, 4, 1, '2026-05-21', '2026-06-21', '2026-05-21', 'active', '2026-05-21 09:32:53', 1),
(23, NULL, 6, 1, '2026-05-21', '2026-06-21', '2026-05-21', 'confirmed', '2026-05-21 09:32:59', 1),
(24, 6, 4, 2, '2026-06-04', '2026-07-04', '2026-06-04', 'active', '2026-06-04 04:27:55', 1),
(25, 6, 4, 4, '2026-06-04', '2026-07-04', '2026-06-04', 'active', '2026-06-04 04:28:26', 1),
(26, NULL, 5, 4, '2026-06-04', '2026-07-04', '2026-06-04', 'confirmed', '2026-06-04 04:28:26', 1);

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `notifications`
-- --------------------------------------------------------
CREATE TABLE `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` int(11) DEFAULT NULL,
  `type` enum('booking','payment','class','alert') DEFAULT 'alert',
  `title` varchar(200) NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `related_id` int(11) DEFAULT NULL,
  KEY `user_id` (`user_id`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

INSERT INTO `notifications` (`id`, `user_id`, `type`, `title`, `message`, `is_read`, `created_at`, `related_id`) VALUES
(46, NULL, 'booking', 'Trạng thái thay đổi', 'Một lịch tập vừa được chuyển sang trạng thái: Hoàn thành.', 1, '2026-05-26 02:48:34', 12),
(47, NULL, 'booking', 'Trạng thái thay đổi', 'Một lịch tập vừa được chuyển sang trạng thái: Hoàn thành.', 1, '2026-05-26 02:44:58', 10),
(49, NULL, 'booking', 'Lịch tập mới', 'Một lịch tập vừa được chuyển sang trạng thái: Hoàn thành.', 1, '2026-05-29 07:31:04', 15),
(55, NULL, 'class', 'Cập nhật trạng thái', 'Lớp học KHÓA HỌC DJ TRUNG CẤP đã được đổi trạng thái thành Đang mở.', 0, '2026-06-09 04:31:14', 6);

-- --------------------------------------------------------
-- Cấu trúc bảng cho bảng `class_messages`
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS `class_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `class_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `message` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  KEY `class_id` (`class_id`),
  KEY `sender_id` (`sender_id`),
  CONSTRAINT `class_messages_ibfk_1` FOREIGN KEY (`class_id`) REFERENCES `classes` (`id`) ON DELETE CASCADE,
  CONSTRAINT `class_messages_ibfk_2` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

SET FOREIGN_KEY_CHECKS = 1;
COMMIT;


