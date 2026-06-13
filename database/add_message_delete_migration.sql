-- ============================================================
-- Migration: Thêm cột is_deleted vào bảng class_messages
-- Chạy file này trên Aiven production DB qua DBeaver
-- ============================================================

ALTER TABLE `class_messages` 
  ADD COLUMN `is_deleted` TINYINT(1) NOT NULL DEFAULT 0;

-- Kiểm tra
SELECT 'is_deleted column added to class_messages!' AS status;
