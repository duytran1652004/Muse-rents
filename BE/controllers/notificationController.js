const db = require('../config/db');

// GET /api/notifications
exports.getAllNotifications = async (req, res) => {
  try {
    const userId = req.user?.id;
    const [rows] = await db.query(
      `SELECT n.*,
       b.id AS b_id, b.booking_date, b.start_time, b.end_time, b.status AS booking_status, b.notes AS b_notes, b.price,
       s.name AS student_name, s.phone AS student_phone, r.name AS room_name, r.image_url AS room_image_url,
       
       c.id AS c_id, c.class_name, c.status AS class_status, c.day_of_week, c.start_time AS c_start_time, c.end_time AS c_end_time,
       c.day_of_week_2, c.start_time_2, c.end_time_2, c.day_of_week_3, c.start_time_3, c.end_time_3,
       c.max_students, c.completed_sessions, c.total_sessions,
       co.name AS course_name, co.image_url AS course_image_url,
       i.name AS instructor_name,
       cr.name AS c_room_name,
       (SELECT GROUP_CONCAT(st.name SEPARATOR ', ') FROM class_enrollments ce JOIN students st ON ce.student_id = st.id WHERE ce.class_id = c.id) AS student_names
       
       FROM notifications n
       LEFT JOIN bookings b ON n.related_id = b.id AND n.type = 'booking'
       LEFT JOIN students s ON b.student_id = s.id
       LEFT JOIN rooms r ON b.room_id = r.id
       
       LEFT JOIN classes c ON n.related_id = c.id AND n.type = 'class'
       LEFT JOIN courses co ON c.course_id = co.id
       LEFT JOIN instructors i ON c.instructor_id = i.id
       LEFT JOIN rooms cr ON c.room_id = cr.id
       
       WHERE n.user_id = ? OR n.user_id IS NULL
       ORDER BY n.created_at DESC LIMIT 50`,
      [userId || null]
    );
    
    const formattedRows = rows.map(row => {
      let booking = null;
      if (row.b_id) {
        let guestName = null;
        let displayName = row.student_name || 'N/A';
        try {
          const notesObj = JSON.parse(row.b_notes);
          if (notesObj.customerType === 'guest' || notesObj.guestName) {
             guestName = notesObj.guestName || 'Khách';
             displayName = guestName;
          }
        } catch(e) {}
        
        booking = {
          id: row.b_id,
          booking_date: row.booking_date,
          start_time: row.start_time,
          end_time: row.end_time,
          status: row.booking_status,
          room_name: row.room_name,
          room_image_url: row.room_image_url,
          student_name: row.student_name,
          guest_name: guestName,
          display_name: displayName,
          price: row.price,
        };
      }
      
      let class_info = null;
      if (row.c_id) {
        class_info = {
          id: row.c_id,
          class_name: row.class_name,
          course_name: row.course_name,
          course_image_url: row.course_image_url,
          instructor_name: row.instructor_name,
          room_name: row.c_room_name,
          day_of_week: row.day_of_week, start_time: row.c_start_time, end_time: row.c_end_time,
          day_of_week_2: row.day_of_week_2, start_time_2: row.start_time_2, end_time_2: row.end_time_2,
          day_of_week_3: row.day_of_week_3, start_time_3: row.start_time_3, end_time_3: row.end_time_3,
          status: row.class_status,
          completed_sessions: row.completed_sessions,
          total_sessions: row.total_sessions,
          student_names: row.student_names,
          max_students: row.max_students,
        };
      }
      
      const { 
        b_id, booking_date, start_time, end_time, booking_status, b_notes, price, student_name, student_phone, room_name, room_image_url,
        c_id, class_name, class_status, day_of_week, c_start_time, c_end_time, day_of_week_2, start_time_2, end_time_2, day_of_week_3, start_time_3, end_time_3, max_students, completed_sessions, total_sessions, course_name, course_image_url, instructor_name, c_room_name, student_names,
        ...notif 
      } = row;
      return { ...notif, booking, class_info };
    });
    
    res.json(formattedRows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

// GET /api/notifications/unread-count
exports.getUnreadCount = async (req, res) => {
  try {
    const userId = req.user?.id;
    const [rows] = await db.query(
      'SELECT COUNT(*) as count FROM notifications WHERE (user_id = ? OR user_id IS NULL) AND is_read = FALSE',
      [userId || null]
    );
    res.json({ count: rows[0].count });
  } catch (err) {
    console.error(err);
    res.json({ count: 0 });
  }
};

// POST /api/notifications/mark-all-read
exports.markAllRead = async (req, res) => {
  try {
    const userId = req.user?.id;
    await db.query(
      'UPDATE notifications SET is_read = TRUE WHERE user_id = ? OR user_id IS NULL',
      [userId || null]
    );
    res.json({ message: 'All notifications marked as read' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

// POST /api/notifications (create)
exports.createNotification = async (req, res) => {
  try {
    const { user_id, type, title, message } = req.body;
    const [result] = await db.query(
      'INSERT INTO notifications (user_id, type, title, message) VALUES (?, ?, ?, ?)',
      [user_id || null, type || 'alert', title, message]
    );
    res.status(201).json({ id: result.insertId, message: 'Notification created' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

// DELETE /api/notifications/:id
exports.deleteNotification = async (req, res) => {
  try {
    await db.query('DELETE FROM notifications WHERE id = ?', [req.params.id]);
    res.json({ message: 'Notification deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

// POST /api/notifications/delete-multiple
exports.deleteMultipleNotifications = async (req, res) => {
  try {
    const { ids } = req.body;
    const userId = req.user?.id;
    if (ids === 'all') {
      await db.query('DELETE FROM notifications WHERE user_id = ? OR user_id IS NULL', [userId || null]);
    } else if (Array.isArray(ids) && ids.length > 0) {
      await db.query('DELETE FROM notifications WHERE id IN (?)', [ids]);
    }
    res.json({ message: 'Notifications deleted' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
