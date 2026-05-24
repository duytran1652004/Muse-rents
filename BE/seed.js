const mysql = require('mysql2');
const pool = mysql.createPool({host:'localhost',user:'root',password:'',database:'muse_rents_db'});

const courses = [
  ['KHÓA HỌC DJ CHUYÊN NGHIỆP', 'Professional DJ Course', 38000000, 'active'],
  ['KHÓA HỌC DJ DÀNH CHO TRẺ EM', 'DJ Kids Course', 7000000, 'active'],
  ['KHÓA HỌC DJ CƠ BẢN', 'Basic DJ Course', 9500000, 'active'],
  ['KHÓA HỌC DJ TRUNG CẤP', 'Intermediate DJ Course', 17000000, 'active'],
  ['KHÓA HỌC DJ NÂNG CAO', 'Advanced DJ Course', 17000000, 'active'],
  ['KHÓA HỌC DJ INFLUENCER', 'Influencer DJ Course', 8000000, 'active'],
  ['KHÓA DJ AFTER HOURS', 'After Hours DJ Course', 5000000, 'active'],
  ['KHÓA HỌC DJ CHUYÊN SÂU DÒNG NHẠC TECHNO', 'Techno Music DJ Course', 27000000, 'active'],
  ['KHÓA HỌC URBAN DJ', 'Urban DJ Course', 29000000, 'active'],
  ['KHÓA HỌC DJ CHUYÊN SÂU DÒNG NHẠC EDM', 'EDM DJ Course', 27000000, 'active']
];

const rooms = [
  ['Production Room', 'Thuê Phòng Tập: Production Room', 4, 0, 'Phòng Production'],
  ['Half Set CDJ 2000 NXS2 - 900 NXS2', 'Thuê phòng tập DJ: Half Set CDJ 2000 NXS2 và Mixer 900 NXS2', 2, 350000, 'CDJ 2000 NXS2, Mixer 900 NXS2'],
  ['Half Set CDJ 3000 - DJM A9', 'Thuê phòng tập DJ: Half Set CDJ 3000 và Mixer DJM - A9', 2, 400000, 'CDJ 3000, Mixer DJM - A9'],
  ['Turntable PLX 1000 - DJM S7', 'Thuê phòng tập DJ: Turntable PLX - 1000 và Mixer DJM S7', 2, 350000, 'Turntable PLX 1000, Mixer DJM S7'],
  ['XDJ - AZ', 'Thuê phòng tập DJ: XDJ - AZ', 2, 300000, 'XDJ - AZ'],
  ['XDJ - XZ', 'Thuê phòng tập DJ: XDJ - XZ', 2, 200000, 'XDJ - XZ'],
  ['XDJ - RX3', 'Thuê phòng tập DJ: XDJ - RX3', 2, 200000, 'XDJ - RX3'],
  ['XDJ - RR', 'Thuê phòng tập DJ: XDJ - RR', 2, 170000, 'XDJ - RR']
];

const students = [
  ['Nipun Patnaik', '09818251489', 'nipunpatnaik@gmail.com', 'active', new Date().toISOString().split('T')[0]],
  ['Hạ Chiêu', '937836892', 'hacheew.ieg@gmail.com', 'active', new Date().toISOString().split('T')[0]],
  ['Minh Anh', '778717859', 'minhanhjulie@gmail.com', 'active', new Date().toISOString().split('T')[0]],
  ['Vũ Thị Hải', '364660082', 'miyukihachi2k3@gmail.com', 'active', new Date().toISOString().split('T')[0]],
  ['Toney', '886234725', 'Nhuphuongtoantran@gmail.com', 'active', new Date().toISOString().split('T')[0]]
];

const classes = [
  [1, 1, 1, 'Lớp DJ Pro Sáng T2-T4', 'Monday', '09:00:00', '11:00:00', 10, 38000000],
  [2, 2, 1, 'Lớp DJ Kids Chiều T7', 'Saturday', '14:00:00', '16:00:00', 8, 7000000],
  [3, 3, 1, 'Lớp DJ Cơ Bản Tối T3-T5', 'Tuesday', '18:30:00', '20:30:00', 12, 9500000]
];

pool.query('INSERT INTO courses (name, description, price, status) VALUES ?', [courses], (err) => {
  if (err) console.error(err);
  else console.log('Courses added');
  
  pool.query('INSERT INTO rooms (name, description, capacity, price_per_hour, facilities) VALUES ?', [rooms], (err) => {
    if (err) console.error(err);
    else console.log('Rooms added');
    
    pool.query('INSERT INTO students (name, phone, email, status, enrollment_date) VALUES ?', [students], (err) => {
      if (err) console.error(err);
      else console.log('Students added');
      
      pool.query('INSERT INTO classes (course_id, room_id, instructor_id, class_name, day_of_week, start_time, end_time, max_students, price_per_class) VALUES ?', [classes], (err) => {
        if (err) console.error(err);
        else console.log('Classes added');
        process.exit(0);
      });
    });
  });
});
