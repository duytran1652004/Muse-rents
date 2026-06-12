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
        c.day_of_week, c.start_time, c.end_time,
        c.day_of_week_2, c.start_time_2, c.end_time_2,
        c.day_of_week_3, c.start_time_3, c.end_time_3,
        c.completed_sessions, c.total_sessions,
        c.price_per_class,
        co.name as course_name,
        co.price as course_price,
        co.image_url as course_image_url,
        r.name as room_name,
        i.name as instructor_name,
        s.name as student_name,
        s.phone as student_phone,
        s.status as student_status,
        u2.full_name as created_by_name
      FROM class_enrollments ce
      LEFT JOIN classes c ON ce.class_id = c.id
      LEFT JOIN courses co ON ce.course_id = co.id OR c.course_id = co.id
      LEFT JOIN rooms r ON c.room_id = r.id
      LEFT JOIN instructors i ON c.instructor_id = i.id
      LEFT JOIN students s ON ce.student_id = s.id
      LEFT JOIN users u2 ON ce.created_by = u2.id
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
    let existingQuery = 'SELECT id FROM class_enrollments WHERE student_id = ? AND status = \'active\'';
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

    if (class_id) {
      const [classInfo] = await db.query('SELECT max_students FROM classes WHERE id = ?', [class_id]);
      if (classInfo.length > 0) {
        const [current] = await db.query('SELECT count(*) as count FROM class_enrollments WHERE class_id = ? AND status != \'dropped\'', [class_id]);
        if (current[0].count >= classInfo[0].max_students) {
          return res.status(400).json({ message: 'Lớp học này đã đủ số lượng học viên tối đa.' });
        }
      }
    }

    const [result] = await db.query(
      'INSERT INTO class_enrollments (student_id, class_id, course_id, start_date, end_date, enrollment_date, status, created_by) VALUES (?, ?, ?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 MONTH), NOW(), \'confirmed\', ?)',
      [student_id, class_id || null, course_id || null, req.user ? req.user.id : null]
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
    const { status, review } = req.body;
    const [enrollment] = await db.query('SELECT student_id, status FROM class_enrollments WHERE id = ?', [req.params.id]);
    
    if (enrollment.length === 0) {
      return res.status(404).json({ message: 'Enrollment not found' });
    }

    if (review !== undefined) {
      await db.query('UPDATE class_enrollments SET review = ? WHERE id = ?', [review, req.params.id]);
    }

    if (status !== undefined && status !== enrollment[0].status) {
      if (enrollment[0].status === 'completed') {
        return res.status(400).json({ message: 'Khóa học đã hoàn thành, không thể thay đổi trạng thái.' });
      }

      if (enrollment[0].status === 'dropped' && status === 'completed') {
        return res.status(400).json({ message: 'Khóa học đã hủy không thể chuyển sang hoàn thành.' });
      }

      if (status === 'active') {
        const [activeOthers] = await db.query(
          'SELECT id FROM class_enrollments WHERE student_id = ? AND status = \'active\' AND id != ?',
          [enrollment[0].student_id, req.params.id]
        );
        if (activeOthers.length > 0) {
          return res.status(400).json({ message: 'Học viên này đang học một khóa khác. Không thể có 2 khóa cùng lúc.' });
        }
      }

      await db.query('UPDATE class_enrollments SET status = ? WHERE id = ?', [status, req.params.id]);
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
    const [enrollment] = await db.query('SELECT student_id, status FROM class_enrollments WHERE id = ?', [req.params.id]);
    
    if (enrollment.length === 0) {
      return res.status(404).json({ message: 'Enrollment not found' });
    }

    if (enrollment[0].status === 'completed') {
      return res.status(400).json({ message: 'Không thể xóa dữ liệu của khóa học đã hoàn thành.' });
    }
    
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

// PUT /api/enrollments/:id/payment
exports.updatePayment = async (req, res) => {
  try {
    const { payment_type, payment_status_1, payment_status_2 } = req.body;
    
    const [enrollment] = await db.query(`
      SELECT ce.id, s.name as student_name, co.name as course_name, c.class_name as class_name,
             co.price as course_price, c.price_per_class as class_price,
             ce.payment_status_1, ce.payment_status_2
      FROM class_enrollments ce
      LEFT JOIN students s ON ce.student_id = s.id
      LEFT JOIN courses co ON ce.course_id = co.id
      LEFT JOIN classes c ON ce.class_id = c.id
      WHERE ce.id = ?
    `, [req.params.id]);
    
    if (enrollment.length === 0) {
      return res.status(404).json({ message: 'Enrollment not found' });
    }

    const oldStatus1 = enrollment[0].payment_status_1 === 'completed';
    const oldStatus2 = enrollment[0].payment_status_2 === 'completed';
    let paidPhase = '';
    const price = Number(enrollment[0].course_price || enrollment[0].class_price || 0);
    let amountPaid = 0;

    let updates = [];
    let params = [];
    let statusChanged = false;

    if (payment_type !== undefined) {
      updates.push('payment_type = ?');
      params.push(payment_type);
    }

    if (payment_status_1 !== undefined) {
      updates.push('payment_status_1 = ?');
      params.push(payment_status_1);
      if (payment_status_1 === 'completed') {
        updates.push('payment_date_1 = NOW()');
        if (!oldStatus1) statusChanged = true;
      } else {
        updates.push('payment_date_1 = NULL');
      }
    }

    if (payment_status_2 !== undefined) {
      updates.push('payment_status_2 = ?');
      params.push(payment_status_2);
      if (payment_status_2 === 'completed') {
        updates.push('payment_date_2 = NOW()');
        if (!oldStatus2) statusChanged = true;
      } else {
        updates.push('payment_date_2 = NULL');
      }
    }

    if (updates.length > 0) {
      params.push(req.params.id);
      await db.query(`UPDATE class_enrollments SET ${updates.join(', ')} WHERE id = ?`, params);
    }
    
    if (statusChanged) {
      const newStatus1 = payment_status_1 === 'completed';
      const newStatus2 = payment_status_2 === 'completed';

      if (payment_type === '100%' && newStatus1 && !oldStatus1) {
        paidPhase = '100%';
        amountPaid = price;
      } else if (payment_type === '50%') {
        if (newStatus1 && !oldStatus1 && newStatus2 && !oldStatus2) {
           paidPhase = 'cả đợt 1 & đợt 2';
           amountPaid = price;
        } else if (newStatus1 && !oldStatus1) {
           paidPhase = 'đợt 1 (50%)';
           amountPaid = price / 2;
        } else if (newStatus2 && !oldStatus2) {
           paidPhase = 'đợt 2 (50%)';
           amountPaid = price / 2;
        }
      }

      if (paidPhase !== '') {
        const d = enrollment[0];
        const cName = d.course_name || d.class_name || 'Khóa học';
        
        // Format currency
        const formattedAmount = new Intl.NumberFormat('vi-VN', { style: 'currency', currency: 'VND' }).format(amountPaid);
        
        const now = new Date();
        const vnTime = new Date(now.getTime() + 7 * 60 * 60 * 1000);
        const hh = String(vnTime.getUTCHours()).padStart(2, '0');
        const mm = String(vnTime.getUTCMinutes()).padStart(2, '0');
        const DD = String(vnTime.getUTCDate()).padStart(2, '0');
        const MM = String(vnTime.getUTCMonth() + 1).padStart(2, '0');
        const YYYY = vnTime.getUTCFullYear();
        const timeStr = `${hh}:${mm} ${DD}/${MM}/${YYYY}`;
        
        const msg = `Học viên: ${d.student_name}\nKhóa học: ${cName}\nThanh toán: ${paidPhase}\nSố tiền: ${formattedAmount}\nThời gian: ${timeStr}`;
        
        await db.query(
          'INSERT INTO notifications (type, title, message, related_id) VALUES (?, ?, ?, ?)',
          ['payment', 'Xác nhận thanh toán', msg, req.params.id]
        );
      }
    }

    res.json({ message: 'Payment updated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

