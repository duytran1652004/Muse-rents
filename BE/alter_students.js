const db = require('./config/db');

async function run() {
  try {
    await db.query("ALTER TABLE students MODIFY COLUMN status ENUM('confirmed', 'active', 'inactive', 'suspended') DEFAULT 'confirmed'");
    console.log("Success students");
  } catch (e) {
    console.error(e);
  } finally {
    process.exit();
  }
}

run();
