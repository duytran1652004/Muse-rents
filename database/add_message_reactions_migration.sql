-- ============================================================
-- Migration: Tạo bảng class_message_reactions cho tính năng thả cảm xúc
-- Chạy file này trên Aiven production DB qua DBeaver
-- ============================================================

CREATE TABLE IF NOT EXISTS `class_message_reactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `message_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `reaction` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  UNIQUE KEY `unique_reaction` (`message_id`, `user_id`),
  CONSTRAINT `fk_msg_reaction` FOREIGN KEY (`message_id`) REFERENCES `class_messages` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_user_reaction` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Kiểm tra xem bảng đã được tạo chưa
SELECT 'class_message_reactions table created successfully!' AS status;
