const db = require('../config/db');

exports.getAllCourses = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM courses ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.getCourseById = async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM courses WHERE id = ?', [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ message: 'Course not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.createCourse = async (req, res) => {
  try {
    const { name, description, price, duration, status } = req.body;
    const image_url = req.file ? `/uploads/${req.file.filename}` : null;
    const [result] = await db.query(
      'INSERT INTO courses (name, description, price, duration, status, image_url) VALUES (?, ?, ?, ?, ?, ?)',
      [name, description, price || 0, duration || null, status || 'active', image_url]
    );
    res.status(201).json({ id: result.insertId, message: 'Course created successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.updateCourse = async (req, res) => {
  try {
    const { name, description, price, duration, status } = req.body;
    let query, params;
    if (req.file) {
      const image_url = `/uploads/${req.file.filename}`;
      query = 'UPDATE courses SET name=?, description=?, price=?, duration=?, status=?, image_url=? WHERE id=?';
      params = [name, description, price, duration, status || 'active', image_url, req.params.id];
    } else {
      query = 'UPDATE courses SET name=?, description=?, price=?, duration=?, status=? WHERE id=?';
      params = [name, description, price, duration, status || 'active', req.params.id];
    }
    await db.query(query, params);
    res.json({ message: 'Course updated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.deleteCourse = async (req, res) => {
  try {
    await db.query('DELETE FROM courses WHERE id = ?', [req.params.id]);
    res.json({ message: 'Course deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
