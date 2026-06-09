const db = require('./config/db');

async function test() {
  try {
    let bookingWhere = "DATE(booking_date) = ?";
    let enrollmentWhere = "DATE(ce.enrollment_date) = ?";
    let queryParams = ['2026-06-09'];

    const [bookingData] = await db.query(`
      SELECT SUM(price) as total_revenue
      FROM bookings
      WHERE status IN ('confirmed', 'completed')
      AND ${bookingWhere}
    `, queryParams);
    console.log('booking', bookingData);

    const [enrollmentData] = await db.query(`
      SELECT 
        COUNT(*) as total_registrations,
        SUM(IFNULL(co.price, 0)) as total_revenue
      FROM class_enrollments ce
      LEFT JOIN classes c ON ce.class_id = c.id
      LEFT JOIN courses co ON ce.course_id = co.id OR c.course_id = co.id
      WHERE ce.status != 'dropped'
      AND ${enrollmentWhere}
    `, queryParams);
    console.log('enrollment', enrollmentData);
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}

test();
