CREATE DATABASE IF NOT EXISTS muse_rents_db;
USE muse_rents_db;

-- Table: users
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(100) NOT NULL,
  phone_number VARCHAR(20) UNIQUE NOT NULL,
  email VARCHAR(100) UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) DEFAULT 'admin',
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  avatar_image VARCHAR(255),
  cover_image VARCHAR(255)
);

-- Table: rooms
CREATE TABLE IF NOT EXISTS rooms (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  capacity INT DEFAULT 0,
  price_per_hour DECIMAL(10, 2) NOT NULL,
  facilities TEXT,
  status ENUM('active', 'maintenance', 'closed') DEFAULT 'active',
  image_url VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: students
CREATE TABLE IF NOT EXISTS students (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(100),
  address VARCHAR(255),
  enrollment_date DATE,
  status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Table: bookings
CREATE TABLE IF NOT EXISTS bookings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  student_id INT,
  room_id INT,
  booking_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  duration_hours INT,
  price DECIMAL(10, 2),
  status ENUM('pending', 'confirmed', 'completed', 'cancelled') DEFAULT 'pending',
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (student_id) REFERENCES students(id),
  FOREIGN KEY (room_id) REFERENCES rooms(id)
);

-- Table: classes
CREATE TABLE IF NOT EXISTS classes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  course_id INT,
  room_id INT,
  instructor_id INT,
  class_name VARCHAR(100) NOT NULL,
  day_of_week ENUM('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'),
  start_time TIME,
  end_time TIME,
  max_students INT,
  price_per_class DECIMAL(10, 2),
  status ENUM('active', 'cancelled') DEFAULT 'active',
  FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE,
  FOREIGN KEY (room_id) REFERENCES rooms(id),
  FOREIGN KEY (instructor_id) REFERENCES users(id)
);

-- Table: class_enrollments
CREATE TABLE IF NOT EXISTS class_enrollments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  class_id INT,
  student_id INT,
  enrollment_date DATE,
  status ENUM('active', 'completed', 'dropped') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (class_id) REFERENCES classes(id),
  FOREIGN KEY (student_id) REFERENCES students(id)
);

-- Table: notifications
CREATE TABLE IF NOT EXISTS notifications (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  type ENUM('booking', 'payment', 'class', 'alert') DEFAULT 'alert',
  title VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Default Admin
INSERT INTO users (full_name, phone_number, email, password_hash, role) 
VALUES ('Admin Muse', '0123456789', 'admin@muse.vn', 'admin123', 'admin');
-- Note: In production, password should be hashed.

-- Sample Students (from provided dataset)
INSERT INTO students (name, phone, email, status, enrollment_date) VALUES
('Nipun Patnaik', '09818251489', 'nipunpatnaik@gmail.com', 'active', CURDATE()),
('Hạ Chiêu', '937836892', 'hacheew.ieg@gmail.com', 'active', CURDATE()),
('Minh Anh', '778717859', 'minhanhjulie@gmail.com', 'active', CURDATE()),
('Vũ Thị Hải', '364660082', 'miyukihachi2k3@gmail.com', 'active', CURDATE()),
('Toney', '886234725', 'Nhuphuongtoantran@gmail.com', 'active', CURDATE());
