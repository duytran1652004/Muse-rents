const mysql = require('mysql2/promise');
require('dotenv').config();

async function run() {
  const db = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT || 3306,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  });

  try {
    console.log('Adding columns...');
    await db.query('ALTER TABLE class_enrollments ADD COLUMN review TEXT');
    console.log('Added review');
  } catch (e) {
    console.log('review error:', e.message);
  }

  try {
    await db.query('ALTER TABLE class_enrollments ADD COLUMN student_review TEXT');
    console.log('Added student_review');
  } catch (e) {
    console.log('student_review error:', e.message);
  }

  db.end();
}

run();
