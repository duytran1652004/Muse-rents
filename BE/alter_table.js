const db = require('./config/db');

async function run() {
  try {
    await db.query("ALTER TABLE class_enrollments MODIFY COLUMN status ENUM('confirmed', 'active', 'completed', 'dropped') DEFAULT 'confirmed'");
    console.log("Success");
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}

run();
