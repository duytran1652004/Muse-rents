const db = require('../config/db');

exports.getAllClasses = async (req, res) => {
  try {
    const { course_id } = req.query;
    let sql = `
      SELECT c.*, co.name as course_name, co.price as course_price
      FROM classes c
      LEFT JOIN courses co ON c.course_id = co.id
    `;
    const params = [];
    if (course_id) {
      sql += ' WHERE c.course_id = ?';
      params.push(course_id);
    }
    sql += ' ORDER BY c.class_name ASC';

    const [rows] = await db.query(sql, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.createClass = async (req, res) => {
  try {
    const { course_id, room_id, instructor_id, class_name, day_of_week, start_time, end_time, max_students, price_per_class } = req.body;
    const [result] = await db.query(
      'INSERT INTO classes (course_id, room_id, instructor_id, class_name, day_of_week, start_time, end_time, max_students, price_per_class) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [course_id, room_id, instructor_id, class_name, day_of_week, start_time, end_time, max_students, price_per_class]
    );
    res.status(201).json({ id: result.insertId, message: 'Class created successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
