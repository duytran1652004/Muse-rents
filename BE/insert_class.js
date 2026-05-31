const db = require('./config/db');
async function run() {
  try {
    await db.query(`
      INSERT INTO classes (
        course_id, room_id, instructor_id, class_name, 
        day_of_week, start_time, end_time, 
        day_of_week_2, start_time_2, end_time_2, 
        day_of_week_3, start_time_3, end_time_3, 
        max_students, price_per_class, status, total_sessions, completed_sessions
      ) VALUES (
        2, 10, 2, 'KHÓA HỌC DJ DÀNH CHO TRẺ EM', 
        'Monday', '14:00:00', '15:00:00', 
        'Wednesday', '14:00:00', '15:00:00', 
        'Friday', '14:00:00', '15:00:00', 
        4, 9500000, 'completed', 8, 8
      )
    `);
    console.log('Inserted');
  } catch (err) {
    console.error(err);
  }
  process.exit(0);
}
run();
