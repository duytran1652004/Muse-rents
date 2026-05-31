const pool = require('../config/db');

const roomSelect = `
  SELECT
    r.id,
    r.name,
    r.description,
    r.capacity,
    r.price_per_hour,
    r.facilities,
    r.image_url,
    r.created_at,
    r.status AS base_status,
    CASE
      WHEN r.status = 'maintenance' THEN 'maintenance'
      WHEN EXISTS (
        SELECT 1
        FROM bookings b
        WHERE b.room_id = r.id
          AND b.status = 'in_progress'
      ) THEN 'occupied'
      ELSE 'available'
    END AS status,
    (
      SELECT COALESCE(
        NULLIF(JSON_UNQUOTE(JSON_EXTRACT(b2.notes, '$.guestName')), ''),
        s.name
      )
      FROM bookings b2
      LEFT JOIN students s ON b2.student_id = s.id
      WHERE b2.room_id = r.id
        AND b2.status = 'in_progress'
      ORDER BY b2.start_time ASC
      LIMIT 1
    ) AS current_tenant
  FROM rooms r
`;

exports.getAllRooms = async (req, res) => {
  try {
    const [rooms] = await pool.query(`${roomSelect} WHERE r.status != "closed" ORDER BY r.created_at DESC`);
    res.json(rooms);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.getRoomById = async (req, res) => {
  try {
    const [rooms] = await pool.query(`${roomSelect} WHERE r.id = ?`, [req.params.id]);
    if (rooms.length === 0) return res.status(404).json({ error: 'Room not found' });
    res.json(rooms[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.createRoom = async (req, res) => {
  const { name, description, capacity, price_per_hour, facilities } = req.body;
  const image_url = req.file ? `/uploads/${req.file.filename}` : null;
  try {
    const [result] = await pool.query(
      'INSERT INTO rooms (name, description, capacity, price_per_hour, facilities, image_url) VALUES (?, ?, ?, ?, ?, ?)',
      [name, description, capacity, price_per_hour, facilities, image_url]
    );
    res.json({ message: 'Room created', roomId: result.insertId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.updateRoom = async (req, res) => {
  const allowedFields = ['name', 'description', 'capacity', 'price_per_hour', 'facilities', 'status'];
  const fields = [];
  const params = [];

  try {
    allowedFields.forEach((field) => {
      if (req.body[field] !== undefined) {
        let value = req.body[field];
        if (field === 'status') {
          if (value === 'available' || value === 'occupied') value = 'active';
          if (!['active', 'maintenance', 'closed'].includes(value)) return;
        }
        fields.push(`${field} = ?`);
        params.push(value);
      }
    });

    if (req.file) {
      fields.push('image_url = ?');
      params.push(`/uploads/${req.file.filename}`);
    }

    if (fields.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    params.push(req.params.id);
    await pool.query(`UPDATE rooms SET ${fields.join(', ')} WHERE id = ?`, params);
    res.json({ message: 'Room updated' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

exports.deleteRoom = async (req, res) => {
  try {
    const [bookings] = await pool.query('SELECT id FROM bookings WHERE room_id = ? LIMIT 1', [req.params.id]);
    if (bookings.length > 0) {
      return res.status(400).json({ error: 'Không thể xóa phòng đã có dữ liệu lịch sử đặt. Xin hãy đổi trạng thái phòng sang Đóng cửa.' });
    }
    await pool.query('DELETE FROM rooms WHERE id = ?', [req.params.id]);
    res.json({ message: 'Room deleted' });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};
