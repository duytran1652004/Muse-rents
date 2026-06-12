const db = require('./BE/config/db');

async function migrate() {
  try {
    await db.query(`
      ALTER TABLE class_enrollments 
      ADD COLUMN payment_type ENUM('100%', '50%') DEFAULT '100%', 
      ADD COLUMN payment_status_1 ENUM('pending', 'completed') DEFAULT 'pending', 
      ADD COLUMN payment_status_2 ENUM('pending', 'completed') DEFAULT 'pending', 
      ADD COLUMN payment_date_1 DATETIME DEFAULT NULL, 
      ADD COLUMN payment_date_2 DATETIME DEFAULT NULL;
    `);
    console.log('Migration successful');
  } catch (err) {
    if (err.code === 'ER_DUP_FIELDNAME') {
      console.log('Fields already exist');
    } else {
      console.error(err);
    }
  }
  process.exit(0);
}

migrate();
