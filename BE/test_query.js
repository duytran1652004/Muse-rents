const db = require('./config/db');

async function test() {
  try {
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
