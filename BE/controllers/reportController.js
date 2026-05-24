const pool = require('../config/db');

exports.getDashboardStats = async (req, res) => {
  try {
    // Auto-complete past confirmed bookings
    await pool.query(
      `UPDATE bookings 
       SET status = 'completed' 
       WHERE status = 'confirmed' 
       AND TIMESTAMP(CONCAT(booking_date, ' ', end_time)) < NOW()`
    );
    const [roomCount] = await pool.query('SELECT COUNT(*) as total FROM rooms WHERE status != "closed"');
    const [studentCount] = await pool.query('SELECT COUNT(*) as total FROM students WHERE status = "active"');
    const [newBookings] = await pool.query('SELECT COUNT(*) as total FROM bookings WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)');
    const [completedBookings] = await pool.query('SELECT COUNT(*) as total FROM bookings WHERE status = "completed"');
    const [revenue] = await pool.query(`
      SELECT SUM(price) as total 
      FROM bookings 
      WHERE status IN ('confirmed', 'completed') 
      AND MONTH(booking_date) = MONTH(CURRENT_DATE())
      AND YEAR(booking_date) = YEAR(CURRENT_DATE())
    `);

    res.json({
      rooms: roomCount[0].total || 0,
      students: studentCount[0].total || 0,
      newBookings: newBookings[0].total || 0,
      completedBookings: completedBookings[0].total || 0,
      revenue: revenue[0].total || 0
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};

