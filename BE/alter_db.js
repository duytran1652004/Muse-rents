const pool = require('./config/db');

async function run() {
  try {
    await pool.query('ALTER TABLE users ADD COLUMN session_token VARCHAR(500) DEFAULT NULL');
    console.log('Column session_token added successfully.');
  } catch (err) {
    if (err.code === 'ER_DUP_FIELDNAME') {
      console.log('Column already exists.');
    } else {
      console.error(err);
    }
  } finally {
    process.exit(0);
  }
}

run();
