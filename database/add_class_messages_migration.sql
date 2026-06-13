-- ============================================================
-- Migration: Tạo bảng class_messages cho tính năng chat lớp học
-- Chạy file này trên Aiven production DB qua DBeaver
-- ============================================================

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

-- Kiểm tra xem bảng đã được tạo chưa
SELECT 'class_messages table created successfully!' AS status;
