const db = require('../config/db');

// GET /api/enrollments?student_id=X
exports.getEnrollments = async (req, res) => {
  try {
    const { student_id, course_id } = req.query;
    let whereClause = [];
    let params = [];
    
    if (student_id) { 
      whereClause.push('ce.student_id = ?'); 
      params.push(student_id); 
    }
    if (course_id) {
      whereClause.push('(ce.course_id = ? OR c.course_id = ?)');
      params.push(course_id, course_id);
    }
    
    let where = whereClause.length > 0 ? 'WHERE ' + whereClause.join(' AND ') : '';

    const [rows] = await db.query(`
      SELECT 
        ce.*,
        c.class_name,
        c.day_of_week,
        c.start_time,
        c.end_time,
        c.price_per_class,
        co.name as course_name,
        co.price as course_price,
        co.image_url as course_image_url,
        r.name as room_name,
        u.full_name as instructor_name,
        s.name as student_name,
        s.phone as student_phone,
        s.status as student_status
      FROM class_enrollments ce
      LEFT JOIN classes c ON ce.class_id = c.id
      LEFT JOIN courses co ON ce.course_id = co.id OR c.course_id = co.id
      LEFT JOIN rooms r ON c.room_id = r.id
      LEFT JOIN users u ON c.instructor_id = u.id
      LEFT JOIN students s ON ce.student_id = s.id
      ${where}
      ORDER BY ce.enrollment_date DESC
    `, params);
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

// Helper to recalculate student status based on enrollments
const recalculateStudentStatus = async (studentId) => {
  try {
    const [rows] = await db.query(
      'SELECT status FROM class_enrollments WHERE student_id = ?',
      [studentId]
    );
    
    let newStatus = 'inactive';
    if (rows.length > 0) {
      if (rows.some(r => r.status === 'active')) newStatus = 'active';
      else if (rows.some(r => r.status === 'confirmed')) newStatus = 'confirmed';
      else if (rows.every(r => r.status === 'completed')) newStatus = 'inactive'; // meaning completed everything
      else if (rows.some(r => r.status === 'dropped')) newStatus = 'suspended';
      else newStatus = 'inactive';
    }
    
    await db.query('UPDATE students SET status = ? WHERE id = ?', [newStatus, studentId]);
  } catch (err) {
    console.error('Error updating student status:', err);
  }
};

// POST /api/enrollments
exports.createEnrollment = async (req, res) => {
  try {
    const { student_id, class_id, course_id } = req.body;

    // Check if already enrolled in this class or course
    let existingQuery = 'SELECT id FROM class_enrollments WHERE student_id = ? AND status = "active"';
    let existingParams = [student_id];
    
    if (class_id) {
      existingQuery += ' AND class_id = ?';
      existingParams.push(class_id);
    } else if (course_id) {
      existingQuery += ' AND course_id = ?';
      existingParams.push(course_id);
    } else {
      return res.status(400).json({ message: 'class_id or course_id is required' });
    }

    const [existing] = await db.query(existingQuery, existingParams);

    if (existing.length > 0) {
      return res.status(200).json({ message: 'Already enrolled', id: existing[0].id });
    }

    const [result] = await db.query(
      'INSERT INTO class_enrollments (student_id, class_id, course_id, start_date, end_date, enrollment_date, status) VALUES (?, ?, ?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 MONTH), NOW(), "confirmed")',
      [student_id, class_id || null, course_id || null]
    );
    
    // Auto update student status to 'active'
    await recalculateStudentStatus(student_id);

    res.status(201).json({ id: result.insertId, message: 'Enrolled successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

// PUT /api/enrollments/:id
exports.updateEnrollment = async (req, res) => {
  try {
    const { status } = req.body;
    const [enrollment] = await db.query('SELECT student_id FROM class_enrollments WHERE id = ?', [req.params.id]);
    
    await db.query('UPDATE class_enrollments SET status = ? WHERE id = ?', [status, req.params.id]);
    
    if (enrollment.length > 0) {
      await recalculateStudentStatus(enrollment[0].student_id);
    }
    
    res.json({ message: 'Enrollment updated' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

// DELETE /api/enrollments/:id
exports.deleteEnrollment = async (req, res) => {
  try {
    const [enrollment] = await db.query('SELECT student_id FROM class_enrollments WHERE id = ?', [req.params.id]);
    
    await db.query('DELETE FROM class_enrollments WHERE id = ?', [req.params.id]);
    
    if (enrollment.length > 0) {
      await recalculateStudentStatus(enrollment[0].student_id);
    }
    
    res.json({ message: 'Enrollment deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
