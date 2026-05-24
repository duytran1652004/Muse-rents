const db = require('../config/db');

// GET /api/notifications
exports.getAllNotifications = async (req, res) => {
  try {
    const userId = req.user?.id;
    const [rows] = await db.query(
      `SELECT n.*,
       b.id AS b_id, b.booking_date, b.start_time, b.end_time, b.status AS booking_status, b.notes AS b_notes, b.price,
       s.name AS student_name, s.phone AS student_phone, r.name AS room_name, r.image_url AS room_image_url
       FROM notifications n
       LEFT JOIN bookings b ON n.related_id = b.id AND n.type = 'booking'
       LEFT JOIN students s ON b.student_id = s.id
       LEFT JOIN rooms r ON b.room_id = r.id
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
      
      const { b_id, booking_date, start_time, end_time, booking_status, b_notes, price, student_name, student_phone, room_name, room_image_url, ...notif } = row;
      return { ...notif, booking };
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
