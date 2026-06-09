const jwt = require('jsonwebtoken');
const pool = require('../config/db');

module.exports = async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) return res.status(401).json({ error: 'Access denied. No token provided.' });

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    
    // Check if this token matches the one in DB
    const [users] = await pool.query('SELECT session_token FROM users WHERE id = ?', [decoded.id]);
    if (users.length === 0) {
      return res.status(401).json({ error: 'Tài khoản không tồn tại.' });
    }
    
    if (users[0].session_token !== token) {
      return res.status(401).json({ error: 'Phiên đăng nhập đã hết hạn do có thiết bị khác đăng nhập.' });
    }

    req.user = decoded;
    next();
  } catch (ex) {
    res.status(401).json({ error: 'Invalid or expired token.' });
  }
};
