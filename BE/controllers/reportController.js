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
    const [roomCount] = await pool.query("SELECT COUNT(*) as total FROM rooms WHERE status != 'closed'");
    const [studentCount] = await pool.query("SELECT COUNT(*) as total FROM students WHERE status = 'active'");
    const [newBookings] = await pool.query('SELECT COUNT(*) as total FROM bookings WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)');
    const [completedBookings] = await pool.query("SELECT COUNT(*) as total FROM bookings WHERE status = 'completed'");
    const [revenue] = await pool.query(`
      SELECT SUM(price) as total 
      FROM bookings 
      WHERE status = 'completed' 
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

exports.getRevenueReport = async (req, res) => {
  try {
    if (!req.user || (req.user.role !== 'admin' && req.user.role !== 'staff')) {
      return res.status(403).json({ error: 'Truy cập bị từ chối. Cần quyền admin hoặc staff.' });
    }

    const { type, date } = req.query; // type: 'day' | 'month', date: 'YYYY-MM-DD' or 'YYYY-MM'
    
    let bookingWhere = '';
    let enrollmentWhere = '';
    let queryParams = [date];
    
    if (type === 'day') {
      bookingWhere = "DATE(booking_date) = ?";
      enrollmentWhere = "DATE(ce.enrollment_date) = ?";
    } else if (type === 'month') {
      bookingWhere = "DATE_FORMAT(booking_date, '%Y-%m') = ?";
      enrollmentWhere = "DATE_FORMAT(ce.enrollment_date, '%Y-%m') = ?";
    } else {
      return res.status(400).json({ error: 'Invalid type. Use "day" or "month"' });
    }

    // 1. Room rental revenue details
    const [bookingData] = await pool.query(`
      SELECT 
        b.id, b.booking_date, b.start_time, b.end_time, b.price, b.notes,
        r.name as room_name, r.image_url as room_image_url, s.name as student_name
      FROM bookings b
      LEFT JOIN rooms r ON b.room_id = r.id
      LEFT JOIN students s ON b.student_id = s.id
      WHERE b.status = 'completed'
      AND r.id IS NOT NULL
      AND ${bookingWhere.replace('booking_date', 'b.booking_date')}
      ORDER BY b.booking_date DESC, b.start_time DESC
    `, queryParams);
    
    let roomRevenue = 0;
    bookingData.forEach(b => roomRevenue += parseFloat(b.price || 0));

    // 2. Course registrations and revenue details
    const [enrollmentData] = await pool.query(`
      SELECT 
        ce.id, ce.enrollment_date, ce.status,
        ce.payment_type, ce.payment_status_1, ce.payment_status_2,
        ce.payment_date_1, ce.payment_date_2,
        c.class_name, co.name as course_name, co.image_url as course_image_url, IFNULL(co.price, c.price_per_class) as price,
        s.name as student_name
      FROM class_enrollments ce
      LEFT JOIN classes c ON ce.class_id = c.id
      LEFT JOIN courses co ON (ce.course_id = co.id OR c.course_id = co.id)
      LEFT JOIN students s ON ce.student_id = s.id
      WHERE ce.status IN ('confirmed', 'active', 'completed')
      AND co.id IS NOT NULL
      AND (c.status IS NULL OR c.status != 'cancelled')
    `);
    
    let courseRevenue = 0;
    const filterPrefix = type === 'day' ? date : date.substring(0, 7);
    const revenueEvents = [];

    enrollmentData.forEach(e => {
      const fullPrice = parseFloat(e.price || 0);
      
      const pDate1Str = e.payment_date_1 ? new Date(new Date(e.payment_date_1).getTime() + 7*3600*1000).toISOString().substring(0, 10) : null;
      const pDate2Str = e.payment_date_2 ? new Date(new Date(e.payment_date_2).getTime() + 7*3600*1000).toISOString().substring(0, 10) : null;

      if (e.payment_status_1 === 'completed' && pDate1Str && pDate1Str.startsWith(filterPrefix)) {
        let amt = e.payment_type === '100%' ? fullPrice : fullPrice / 2;
        courseRevenue += amt;
        revenueEvents.push({
          ...e,
          paid_amount: amt,
          enrollment_date: e.payment_date_1, // use payment date for display
          payment_phase: e.payment_type === '100%' ? '100%' : 'Đợt 1 (50%)'
        });
      }

      if (e.payment_type === '50%' && e.payment_status_2 === 'completed' && pDate2Str && pDate2Str.startsWith(filterPrefix)) {
        courseRevenue += fullPrice / 2;
        revenueEvents.push({
          ...e,
          paid_amount: fullPrice / 2,
          enrollment_date: e.payment_date_2, // use payment date for display
          payment_phase: 'Đợt 2 (50%)'
        });
      }
    });

    revenueEvents.sort((a, b) => new Date(b.enrollment_date) - new Date(a.enrollment_date));
    const courseRegistrations = revenueEvents.length;

    res.json({
      roomRevenue: roomRevenue,
      courseRegistrations: courseRegistrations,
      courseRevenue: courseRevenue,
      totalRevenue: roomRevenue + courseRevenue,
      bookings: bookingData,
      enrollments: revenueEvents
    });

  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
};
