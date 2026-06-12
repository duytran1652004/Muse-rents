const db = require('../config/db');

exports.getAllClasses = async (req, res) => {
  try {
    const { course_id, instructor_id, room_id, status } = req.query;
    let where = [];
    let params = [];

    if (course_id) { where.push('c.course_id = ?'); params.push(course_id); }
    if (room_id) { where.push('c.room_id = ?'); params.push(room_id); }
    if (status && status !== 'all') { where.push('c.status = ?'); params.push(status); }

    if (req.user && req.user.role === 'teacher') {
      const [instructor] = await db.query('SELECT id FROM instructors WHERE user_id = ?', [req.user.id]);
      if (instructor.length > 0) {
        where.push('c.instructor_id = ?');
        params.push(instructor[0].id);
      } else {
        where.push('1 = 0'); // No classes if no profile
      }
    } else if (instructor_id) {
      where.push('c.instructor_id = ?');
      params.push(instructor_id);
    }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';
    
    const [rows] = await db.query(`
      SELECT 
        c.*, 
        co.name AS course_name, 
        co.image_url AS course_image_url,
        r.name AS room_name, 
        i.name AS instructor_name,
        u.full_name AS created_by_name,
        (SELECT COUNT(id) FROM class_enrollments WHERE class_id = c.id AND status != 'dropped') AS current_students,
        (SELECT GROUP_CONCAT(s.name SEPARATOR ', ') FROM class_enrollments ce JOIN students s ON ce.student_id = s.id WHERE ce.class_id = c.id AND ce.status != 'dropped') AS student_names,
        (SELECT CONCAT('[', IFNULL(GROUP_CONCAT(JSON_OBJECT('id', s.id, 'enrollment_id', ce.id, 'name', s.name, 'phone', IFNULL(s.phone, ''), 'email', IFNULL(s.email, ''), 'status', IFNULL(s.status, ''), 'review', IFNULL(ce.review, ''))), ''), ']') FROM class_enrollments ce JOIN students s ON ce.student_id = s.id WHERE ce.class_id = c.id AND ce.status != 'dropped') AS students_json
      FROM classes c
      LEFT JOIN courses co ON c.course_id = co.id
      LEFT JOIN rooms r ON c.room_id = r.id
      LEFT JOIN instructors i ON c.instructor_id = i.id
      LEFT JOIN users u ON c.created_by = u.id
      ${whereClause}
      ORDER BY c.id DESC
    `, params);
    
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.getClassById = async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT 
        c.*, 
        co.name AS course_name, 
        co.image_url AS course_image_url,
        r.name AS room_name, 
        i.name AS instructor_name,
        u.full_name AS created_by_name,
        (SELECT COUNT(id) FROM class_enrollments WHERE class_id = c.id AND status != 'dropped') AS current_students,
        (SELECT GROUP_CONCAT(s.name SEPARATOR ', ') FROM class_enrollments ce JOIN students s ON ce.student_id = s.id WHERE ce.class_id = c.id AND ce.status != 'dropped') AS student_names,
        (SELECT CONCAT('[', IFNULL(GROUP_CONCAT(JSON_OBJECT('id', s.id, 'enrollment_id', ce.id, 'name', s.name, 'phone', IFNULL(s.phone, ''), 'email', IFNULL(s.email, ''), 'status', IFNULL(s.status, ''), 'review', IFNULL(ce.review, ''))), ''), ']') FROM class_enrollments ce JOIN students s ON ce.student_id = s.id WHERE ce.class_id = c.id AND ce.status != 'dropped') AS students_json
      FROM classes c
      LEFT JOIN courses co ON c.course_id = co.id
      LEFT JOIN rooms r ON c.room_id = r.id
      LEFT JOIN instructors i ON c.instructor_id = i.id
      LEFT JOIN users u ON c.created_by = u.id
      WHERE c.id = ?
    `, [req.params.id]);
    
    if (rows.length === 0) return res.status(404).json({ message: 'Class not found' });
    res.json(rows[0]);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.createClass = async (req, res) => {
  try {
    const { 
      course_id, room_id, instructor_id, class_name, 
      day_of_week, start_time, end_time, 
      day_of_week_2, start_time_2, end_time_2,
      day_of_week_3, start_time_3, end_time_3,
      max_students, price_per_class, status,
      total_sessions, student_ids
    } = req.body;
    
    const [result] = await db.query(
      `INSERT INTO classes (
        course_id, room_id, instructor_id, class_name, 
        day_of_week, start_time, end_time, 
        day_of_week_2, start_time_2, end_time_2,
        day_of_week_3, start_time_3, end_time_3,
        max_students, price_per_class, status, total_sessions, created_by
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        course_id, room_id || null, instructor_id || null, class_name, 
        day_of_week || null, start_time || null, end_time || null, 
        day_of_week_2 || null, start_time_2 || null, end_time_2 || null,
        day_of_week_3 || null, start_time_3 || null, end_time_3 || null,
        max_students || 4, price_per_class || 0, status || 'active', total_sessions || 0, req.user ? req.user.id : null
      ]
    );

    const classId = result.insertId;

    if (student_ids && Array.isArray(student_ids) && student_ids.length > 0) {
      for (let sid of student_ids) {
        const [activeOther] = await db.query('SELECT id FROM class_enrollments WHERE student_id = ? AND status = "active"', [sid]);
        if (activeOther.length > 0) continue; // Skip if already active in another class

        const [existing] = await db.query('SELECT id FROM class_enrollments WHERE student_id = ? AND course_id = ?', [sid, course_id]);
        if (existing.length > 0) {
          await db.query('UPDATE class_enrollments SET class_id = ?, status = "active" WHERE id = ?', [classId, existing[0].id]);
        } else {
          await db.query('INSERT INTO class_enrollments (student_id, class_id, course_id, enrollment_date, status, created_by) VALUES (?, ?, ?, CURDATE(), "active", ?)', [sid, classId, course_id, req.user ? req.user.id : null]);
        }
      }
      
      // Update global status for these students
      await db.query(`
        UPDATE students s 
        SET status = IF(EXISTS(SELECT 1 FROM class_enrollments ce WHERE ce.student_id = s.id AND ce.status = "active"), "active", "confirmed") 
        WHERE id IN (?)`, [student_ids]
      );
    }

    try {
      await db.query(
        'INSERT INTO notifications (type, title, message, related_id) VALUES (?, ?, ?, ?)',
        ['class', 'Lớp học mới', `Lớp học ${class_name || 'mới'} vừa được tạo.`, classId]
      );
    } catch (notifErr) {
      console.error('Lỗi khi tạo thông báo:', notifErr);
    }

    res.status(201).json({ id: classId, message: 'Class created successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.updateClass = async (req, res) => {
  try {
    const [existingRows] = await db.query('SELECT * FROM classes WHERE id = ?', [req.params.id]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Class not found' });
    }
    const existing = existingRows[0];

    if (req.body.completed_sessions !== undefined) {
      let newTotal = req.body.total_sessions !== undefined ? req.body.total_sessions : existing.total_sessions;
      if (req.body.completed_sessions >= newTotal && newTotal > 0) {
        req.body.completed_sessions = newTotal;
        req.body.status = 'completed';
      } else if (req.body.completed_sessions < newTotal && existing.status === 'completed' && req.body.status === undefined) {
        req.body.status = 'active';
      }
    }

    if (req.body.is_in_session !== undefined) {
      // Room status is dynamically calculated in roomController.js based on is_in_session
      // No need to update rooms table directly.
    }

    const allowedFields = [
      'course_id', 'room_id', 'instructor_id', 'class_name', 
      'day_of_week', 'start_time', 'end_time', 
      'day_of_week_2', 'start_time_2', 'end_time_2',
      'day_of_week_3', 'start_time_3', 'end_time_3',
      'max_students', 'price_per_class', 'status',
      'total_sessions', 'completed_sessions', 'is_in_session'
    ];
    const fields = [];
    const params = [];
    
    allowedFields.forEach(field => {
      if (req.body[field] !== undefined) {
        fields.push(`${field} = ?`);
        params.push(req.body[field]);
      }
    });

    if (fields.length > 0) {
      params.push(req.params.id);
      await db.query(`UPDATE classes SET ${fields.join(', ')} WHERE id = ?`, params);
    }

    if (req.body.student_ids !== undefined) {
      const student_ids = req.body.student_ids;
      
      // Lấy danh sách học viên cũ để cập nhật lại trạng thái
      const [oldEnrollments] = await db.query('SELECT student_id FROM class_enrollments WHERE class_id = ?', [req.params.id]);
      const oldStudentIds = oldEnrollments.map(e => e.student_id);

      // Remove students from this class
      await db.query('UPDATE class_enrollments SET class_id = NULL, status = "confirmed" WHERE class_id = ?', [req.params.id]);
      
      if (Array.isArray(student_ids) && student_ids.length > 0) {
        const courseId = req.body.course_id || existing.course_id;
        for (let sid of student_ids) {
          if (courseId) {
            const [activeOther] = await db.query('SELECT id FROM class_enrollments WHERE student_id = ? AND status = "active" AND class_id != ?', [sid, req.params.id]);
            if (activeOther.length > 0) continue;

            const [existingE] = await db.query('SELECT id FROM class_enrollments WHERE student_id = ? AND course_id = ?', [sid, courseId]);
            if (existingE.length > 0) {
              await db.query('UPDATE class_enrollments SET class_id = ?, status = "active" WHERE id = ?', [req.params.id, existingE[0].id]);
            } else {
              await db.query('INSERT INTO class_enrollments (student_id, class_id, course_id, enrollment_date, status, created_by) VALUES (?, ?, ?, CURDATE(), "active", ?)', [sid, req.params.id, courseId, req.user ? req.user.id : null]);
            }
          }
        }
      }

      // Cập nhật lại global status cho tất cả những người bị ảnh hưởng
      const allAffectedIds = [...new Set([...oldStudentIds, ...(Array.isArray(student_ids) ? student_ids : [])])];
      if (allAffectedIds.length > 0) {
        await db.query(`
          UPDATE students s 
          SET status = IF(EXISTS(SELECT 1 FROM class_enrollments ce WHERE ce.student_id = s.id AND ce.status = "active"), "active", "confirmed") 
          WHERE id IN (?)`, [allAffectedIds]
        );
      }
    }

    let notifTitle = '';
    let notifMessage = '';
    
    if (req.body.completed_sessions !== undefined && req.body.completed_sessions !== existing.completed_sessions) {
      notifTitle = 'Cập nhật tiến độ học';
      if (req.body.status === 'completed' && existing.status !== 'completed') {
        notifMessage = `Lớp học ${existing.class_name} đã học xong buổi thứ ${req.body.completed_sessions} và chính thức Hoàn thành.`;
      } else {
        notifMessage = `Lớp học ${existing.class_name} vừa hoàn thành buổi học thứ ${req.body.completed_sessions}.`;
      }
    } else if (req.body.status !== undefined && req.body.status !== existing.status) {
      notifTitle = 'Cập nhật trạng thái';
      const st = req.body.status === 'completed' ? 'Hoàn thành' : (req.body.status === 'active' ? 'Đang mở' : 'Tạm dừng');
      notifMessage = `Lớp học ${existing.class_name} đã được đổi trạng thái thành ${st}.`;
    } else if (fields.length > 0 || req.body.student_ids !== undefined) {
      notifTitle = 'Cập nhật lớp học';
      notifMessage = `Thông tin lớp học ${existing.class_name} vừa được thay đổi.`;
    }

    if (notifTitle && notifMessage) {
      try {
        const [existingNotif] = await db.query(
          'SELECT id FROM notifications WHERE type = ? AND related_id = ? ORDER BY created_at DESC LIMIT 1',
          ['class', existing.id]
        );

        if (existingNotif.length > 0) {
          // Cập nhật thông báo cũ và đánh dấu chưa đọc (is_read = 0)
          await db.query(
            'UPDATE notifications SET title = ?, message = ?, created_at = NOW(), is_read = 0 WHERE id = ?',
            [notifTitle, notifMessage, existingNotif[0].id]
          );
        } else {
          // Tạo mới nếu chưa có
          await db.query(
            'INSERT INTO notifications (type, title, message, related_id) VALUES (?, ?, ?, ?)',
            ['class', notifTitle, notifMessage, existing.id]
          );
        }
      } catch (e) {
        console.error('Lỗi khi tạo/cập nhật thông báo lớp:', e);
      }
    }

    res.json({ message: 'Class updated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.deleteClass = async (req, res) => {
  try {
    const [cls] = await db.query('SELECT status FROM classes WHERE id = ?', [req.params.id]);
    if (cls.length > 0) {
      if (cls[0].status === 'completed') {
        return res.status(400).json({ message: 'Không thể xóa lớp học đã hoàn thành.' });
      }
      if (cls[0].status === 'active') {
        return res.status(400).json({ message: 'Không thể xóa lớp học đang hoạt động. Vui lòng tạm dừng trước khi xóa.' });
      }
    }

    const [enrollments] = await db.query('SELECT student_id FROM class_enrollments WHERE class_id = ?', [req.params.id]);
    const studentIds = enrollments.map(e => e.student_id);

    // Trả khóa học lại cho học viên bằng cách set class_id = NULL và status = 'confirmed'
    await db.query('UPDATE class_enrollments SET class_id = NULL, status = "confirmed" WHERE class_id = ?', [req.params.id]);

    // Xóa lớp học
    await db.query('DELETE FROM classes WHERE id = ?', [req.params.id]);

    // Cập nhật lại trạng thái học viên
    if (studentIds.length > 0) {
      for (const sid of studentIds) {
        await db.query(`
          UPDATE students s 
          SET status = IF(EXISTS(SELECT 1 FROM class_enrollments ce WHERE ce.student_id = s.id AND ce.status = "active"), "active", "confirmed") 
          WHERE id = ?`, [sid]
        );
      }
    }

    // Xóa các thông báo liên quan đến lớp
    try {
      await db.query('DELETE FROM notifications WHERE type = "class" AND related_id = ?', [req.params.id]);
    } catch (e) {
      console.error('Lỗi khi xóa thông báo:', e);
    }

    res.json({ message: 'Class deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
