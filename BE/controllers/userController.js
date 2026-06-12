const db = require('../config/db');

exports.getAllUsers = async (req, res) => {
  try {
    const [users] = await db.query('SELECT id, full_name, phone_number, email, role, avatar_image, status, created_at FROM users ORDER BY created_at DESC');
    res.json(users);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Lỗi server' });
  }
};

exports.updateUser = async (req, res) => {
  const { full_name, phone_number, email, role, status, linked_student_id } = req.body;
  try {
    // Check if phone or email is duplicate
    if (phone_number) {
      const [existsPhone] = await db.query('SELECT id FROM users WHERE phone_number = ? AND id != ?', [phone_number, req.params.id]);
      if (existsPhone.length > 0) return res.status(400).json({ message: 'Số điện thoại đã tồn tại' });
    }
    if (email) {
      const [existsEmail] = await db.query('SELECT id FROM users WHERE email = ? AND id != ?', [email, req.params.id]);
      if (existsEmail.length > 0) return res.status(400).json({ message: 'Email đã tồn tại' });
    }

    const [user] = await db.query('SELECT role, status FROM users WHERE id = ?', [req.params.id]);
    if (user.length === 0) return res.status(404).json({ message: 'Không tìm thấy người dùng' });

    const oldRole = user[0].role;
    const oldStatus = user[0].status;

    const [currentUser] = await db.query('SELECT role FROM users WHERE id = ?', [req.user.id]);
    const currentRole = currentUser.length > 0 ? currentUser[0].role : null;

    if (currentRole === 'staff') {
      if (oldRole === 'admin') {
        return res.status(403).json({ message: 'Nhân viên không thể chỉnh sửa tài khoản quản trị viên' });
      }
      if (role === 'admin') {
        return res.status(403).json({ message: 'Nhân viên không thể cấp quyền quản trị viên' });
      }
    }

    await db.query(
      'UPDATE users SET full_name = COALESCE(?, full_name), phone_number = COALESCE(?, phone_number), email = COALESCE(?, email), role = COALESCE(?, role), status = COALESCE(?, status) WHERE id = ?',
      [full_name, phone_number, email, role, status, req.params.id]
    );

    // If role changed to teacher, make sure they have an instructor record
    if (role === 'teacher' && oldRole !== 'teacher') {
      const [instructor] = await db.query('SELECT id FROM instructors WHERE user_id = ?', [req.params.id]);
      if (instructor.length === 0) {
        await db.query(
          'INSERT INTO instructors (name, phone, email, status, user_id) VALUES (?, ?, ?, ?, ?)',
          [full_name || '', phone_number || '', email || '', 'active', req.params.id]
        );
      } else {
        await db.query('UPDATE instructors SET status = \'active\' WHERE user_id = ?', [req.params.id]);
      }
    } else if (role !== 'teacher' && oldRole === 'teacher') {
      // If role changed from teacher to something else, deactivate their instructor record
      await db.query('UPDATE instructors SET status = \'inactive\' WHERE user_id = ?', [req.params.id]);
    }

    // If role changed to student, or status became active as a student
    if (role === 'student' && (oldRole !== 'student' || oldStatus === 'pending')) {
      if (linked_student_id) {
        // Link to an existing student
        await db.query('UPDATE students SET user_id = ?, status = \'active\' WHERE id = ?', [req.params.id, linked_student_id]);
      } else {
        const [student] = await db.query('SELECT id FROM students WHERE user_id = ?', [req.params.id]);
        if (student.length === 0) {
          await db.query(
            'INSERT INTO students (name, phone, email, status, enrollment_date, user_id) VALUES (?, ?, ?, ?, CURDATE(), ?)',
            [full_name || '', phone_number || '', email || '', 'active', req.params.id]
          );
        } else {
          await db.query('UPDATE students SET status = \'active\' WHERE user_id = ?', [req.params.id]);
        }
      }
    } else if (role !== 'student' && oldRole === 'student') {
      await db.query('UPDATE students SET status = \'inactive\' WHERE user_id = ?', [req.params.id]);
    }

    res.json({ message: 'Cập nhật thành công' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Lỗi server' });
  }
};

exports.deleteUser = async (req, res) => {
  try {
    // Cannot delete yourself
    if (req.user.id == req.params.id) {
      return res.status(400).json({ message: 'Không thể xóa chính bạn' });
    }

    const [currentUser] = await db.query('SELECT role FROM users WHERE id = ?', [req.user.id]);
    const currentRole = currentUser.length > 0 ? currentUser[0].role : null;

    const [targetUser] = await db.query('SELECT role FROM users WHERE id = ?', [req.params.id]);
    if (targetUser.length === 0) return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    
    if (currentRole === 'staff' && targetUser[0].role === 'admin') {
        return res.status(403).json({ message: 'Nhân viên không thể xóa tài khoản quản trị viên' });
    }
    
    // Check if they are an instructor with active classes
    const [instructor] = await db.query('SELECT id FROM instructors WHERE user_id = ?', [req.params.id]);
    if (instructor.length > 0) {
      const [classes] = await db.query('SELECT id FROM classes WHERE instructor_id = ? AND status = \'active\'', [instructor[0].id]);
      if (classes.length > 0) {
         return res.status(400).json({ message: 'Không thể xóa người dùng này vì họ đang dạy một hoặc nhiều lớp.' });
      }
      // If no active classes, we can delete the instructor record or just set to inactive. Let's delete it.
      await db.query('DELETE FROM instructors WHERE user_id = ?', [req.params.id]);
    }

    // Check if they are a student with active enrollments
    const [student] = await db.query('SELECT id FROM students WHERE user_id = ?', [req.params.id]);
    if (student.length > 0) {
      const [bookings] = await db.query('SELECT id FROM bookings WHERE student_id = ? AND status IN (\'pending\', \'confirmed\', \'in_progress\')', [student[0].id]);
      if (bookings.length > 0) {
          return res.status(400).json({ message: 'Không thể xóa người dùng này vì họ có lịch tập chưa hoàn thành.' });
      }
      const [enrollments] = await db.query('SELECT id FROM class_enrollments WHERE student_id = ? AND status IN (\'active\', \'confirmed\')', [student[0].id]);
      if (enrollments.length > 0) {
          return res.status(400).json({ message: 'Không thể xóa người dùng này vì họ đang tham gia khóa học.' });
      }
      await db.query('DELETE FROM students WHERE user_id = ?', [req.params.id]);
    }

    await db.query('DELETE FROM users WHERE id = ?', [req.params.id]);
    res.json({ message: 'Xóa người dùng thành công' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Lỗi server' });
  }
};
