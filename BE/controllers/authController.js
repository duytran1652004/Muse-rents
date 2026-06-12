const pool = require('../config/db');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

exports.register = async (req, res) => {
  const { full_name, phone, username, email, password, role } = req.body;
  try {
    // Check if user exists
    const [exists] = await pool.query('SELECT id FROM users WHERE phone_number = ? OR email = ? OR username = ?', [phone, email, username]);
    if (exists.length > 0) {
      return res.status(400).json({ error: 'Số điện thoại, Email hoặc Tên tài khoản đã tồn tại' });
    }

    const assignedRole = role && ['admin', 'staff', 'teacher'].includes(role) ? role : 'staff';
    const hashedPassword = await bcrypt.hash(password, 10);
    const [result] = await pool.query(
      'INSERT INTO users (full_name, phone_number, username, email, password_hash, role) VALUES (?, ?, ?, ?, ?, ?)',
      [full_name, phone, username, email, hashedPassword, assignedRole]
    );

    const userId = result.insertId;

    if (assignedRole === 'teacher') {
      await pool.query(
        'INSERT INTO instructors (name, phone, email, status, user_id) VALUES (?, ?, ?, ?, ?)',
        [full_name, phone, email, 'active', userId]
      );
    }


    res.json({ message: 'Đăng ký thành công', userId: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.login = async (req, res) => {
  const { identifier, password } = req.body;
  try {
    const [users] = await pool.query(
      'SELECT * FROM users WHERE phone_number = ? OR email = ? OR username = ?',
      [identifier, identifier, identifier]
    );

    if (users.length === 0) {
      return res.status(401).json({ error: 'Tài khoản không tồn tại' });
    }

    const user = users[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    
    if (!isMatch) {
      return res.status(401).json({ error: 'Mật khẩu không chính xác' });
    }

    const token = jwt.sign(
      { id: user.id, role: user.role },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    await pool.query('UPDATE users SET session_token = ? WHERE id = ?', [token, user.id]);

    res.json({
      token,
      user: {
        id: user.id,
        full_name: user.full_name,
        phone: user.phone_number,
        email: user.email,
        role: user.role
      }
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getProfile = async (req, res) => {
  try {
    const [users] = await pool.query('SELECT id, full_name, username, phone_number, email, role, avatar_image FROM users WHERE id = ?', [req.user.id]);
    if (users.length === 0) return res.status(404).json({ error: 'User not found' });
    res.json(users[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateProfile = async (req, res) => {
  const { full_name, phone, username, email, current_password, new_password } = req.body;
  try {
    const [users] = await pool.query('SELECT * FROM users WHERE id = ?', [req.user.id]);
    if (users.length === 0) return res.status(404).json({ error: 'User not found' });

    const user = users[0];

    // Validate phone/email/username uniqueness
    if (phone && phone !== user.phone_number) {
      const [existing] = await pool.query('SELECT id FROM users WHERE phone_number = ? AND id != ?', [phone, req.user.id]);
      if (existing.length > 0) return res.status(400).json({ error: 'Số điện thoại đã được sử dụng' });
    }
    if (email && email !== user.email) {
      const [existing] = await pool.query('SELECT id FROM users WHERE email = ? AND id != ?', [email, req.user.id]);
      if (existing.length > 0) return res.status(400).json({ error: 'Email đã được sử dụng' });
    }
    if (username && username !== user.username) {
      const [existing] = await pool.query('SELECT id FROM users WHERE username = ? AND id != ?', [username, req.user.id]);
      if (existing.length > 0) return res.status(400).json({ error: 'Tên tài khoản đã được sử dụng' });
    }

    // If changing password
    if (new_password) {
      if (!current_password) return res.status(400).json({ error: 'Vui lòng nhập mật khẩu hiện tại' });
      const isMatch = await bcrypt.compare(current_password, user.password_hash);
      if (!isMatch) return res.status(401).json({ error: 'Mật khẩu hiện tại không đúng' });
      const hashed = await bcrypt.hash(new_password, 10);
      await pool.query('UPDATE users SET password_hash = ? WHERE id = ?', [hashed, req.user.id]);
    }

    // Update profile fields
    await pool.query(
      'UPDATE users SET full_name = COALESCE(?, full_name), phone_number = COALESCE(?, phone_number), username = COALESCE(?, username), email = COALESCE(?, email) WHERE id = ?',
      [full_name || null, phone || null, username || null, email || null, req.user.id]
    );

    const [updated] = await pool.query('SELECT id, full_name, username, phone_number, email, role FROM users WHERE id = ?', [req.user.id]);
    res.json({ message: 'Cập nhật thành công', user: updated[0] });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
