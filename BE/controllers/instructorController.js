const db = require('../config/db');

exports.getAllInstructors = async (req, res) => {
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
    const [rows] = await db.query(`SELECT * FROM instructors ${whereClause} ORDER BY created_at DESC`, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.getInstructorById = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM instructors WHERE id = ?', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ message: 'Instructor not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.createInstructor = async (req, res) => {
  try {
    const { name, phone, email, bio, status } = req.body;
    const [result] = await db.query(
      'INSERT INTO instructors (name, phone, email, bio, status) VALUES (?, ?, ?, ?, ?)',
      [name, phone, email, bio, status || 'active']
    );
    res.status(201).json({ id: result.insertId, message: 'Instructor created successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.updateInstructor = async (req, res) => {
  try {
    const { name, phone, email, bio, status } = req.body;
    const fields = [];
    const params = [];
    if (name !== undefined) { fields.push('name = ?'); params.push(name); }
    if (phone !== undefined) { fields.push('phone = ?'); params.push(phone); }
    if (email !== undefined) { fields.push('email = ?'); params.push(email); }
    if (bio !== undefined) { fields.push('bio = ?'); params.push(bio); }
    if (status !== undefined) { fields.push('status = ?'); params.push(status); }
    if (fields.length === 0) return res.status(400).json({ message: 'No fields to update' });
    params.push(req.params.id);
    await db.query(`UPDATE instructors SET ${fields.join(', ')} WHERE id = ?`, params);
    res.json({ message: 'Instructor updated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.deleteInstructor = async (req, res) => {
  try {
    const [classes] = await db.query('SELECT id FROM classes WHERE instructor_id = ? AND status = \'active\'', [req.params.id]);
    if (classes.length > 0) {
      return res.status(400).json({ message: 'Không thể xóa giáo viên đang có lớp học đang hoạt động.' });
    }
    
    const [history] = await db.query('SELECT id FROM classes WHERE instructor_id = ? LIMIT 1', [req.params.id]);
    if (history.length > 0) {
       return res.status(400).json({ message: 'Không thể xóa giáo viên đã có lịch sử giảng dạy. Hãy đổi trạng thái sang Không hoạt động.' });
    }

    await db.query('DELETE FROM instructors WHERE id = ?', [req.params.id]);
    res.json({ message: 'Instructor deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
