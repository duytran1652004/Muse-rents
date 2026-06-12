const db = require('../config/db');

exports.getAllStudents = async (req, res) => {
  try {
    const { search, status } = req.query;
    let where = [];
    let params = [];

    if (search) {
      where.push('(name LIKE ? OR phone LIKE ? OR email LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }
    if (status && status !== 'all') { where.push('status = ?'); params.push(status); }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';
    const [rows] = await db.query(`SELECT * FROM students ${whereClause} ORDER BY created_at DESC`, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.getStudentById = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM students WHERE id = ?', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ message: 'Student not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.createStudent = async (req, res) => {
  try {
    const { name, phone, email, address, status } = req.body;
    const [result] = await db.query(
      'INSERT INTO students (name, phone, email, address, enrollment_date, status) VALUES (?, ?, ?, ?, CURDATE(), ?)',
      [name, phone, email, address, status || 'active']
    );
    res.status(201).json({ id: result.insertId, message: 'Student created successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.updateStudent = async (req, res) => {
  try {
    const { name, phone, email, address, status } = req.body;
    // Only update provided fields
    const fields = [];
    const params = [];
    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (phone !== undefined) { fields.push('phone = ?'); params.push(phone); }
    if (email !== undefined) { fields.push('email = ?'); params.push(email); }
    if (address !== undefined) { fields.push('address = ?'); params.push(address); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }
    if (fields.length === 0) return res.status(400).json({ message: 'No fields to update' });
    params.push(req.params.id);
    await db.query(`UPDATE students SET ${fields.join(', ')} WHERE id = ?`, params);
    res.json({ message: 'Student updated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.deleteStudent = async (req, res) => {
  try {
    const [bookings] = await db.query('SELECT id FROM bookings WHERE student_id = ? AND status IN (\'pending\', \'confirmed\', \'in_progress\')', [req.params.id]);
    if (bookings.length > 0) {
      return res.status(400).json({ message: 'Không thể xóa học viên đang có lịch tập sắp tới hoặc đang sử dụng.' });
    }
    
    const [enrollments] = await db.query('SELECT id FROM class_enrollments WHERE student_id = ? AND status IN (\'active\', \'confirmed\')', [req.params.id]);
    if (enrollments.length > 0) {
      return res.status(400).json({ message: 'Không thể xóa học viên đang tham gia khóa học.' });
    }

    await db.query('DELETE FROM students WHERE id = ?', [req.params.id]);
    res.json({ message: 'Student deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
