-- ============================================================
-- Migration: Tạo bảng class_message_reactions (emoji reactions)
-- Chạy trên Aiven production DB qua DBeaver
-- ============================================================

CREATE TABLE IF NOT EXISTS `class_message_reactions` (
  `id` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `message_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `emoji` varchar(10) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  UNIQUE KEY `unique_user_message` (`message_id`, `user_id`),
  KEY `message_id` (`message_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `reactions_ibfk_1` FOREIGN KEY (`message_id`) REFERENCES `class_messages` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reactions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

SELECT 'class_message_reactions table created!' AS status;
