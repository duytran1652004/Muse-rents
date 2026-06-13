const mysql = require('mysql2/promise');
require('dotenv').config();

async function runMigrations() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: { rejectUnauthorized: false }
  });

  try {
    console.log('Adding file attachment columns to class_messages...');
    await connection.query('ALTER TABLE `class_messages` ADD COLUMN `file_url` VARCHAR(255) DEFAULT NULL');
    await connection.query('ALTER TABLE `class_messages` ADD COLUMN `file_name` VARCHAR(255) DEFAULT NULL');
    await connection.query('ALTER TABLE `class_messages` ADD COLUMN `file_type` VARCHAR(50) DEFAULT NULL');
    console.log('✅ Columns added successfully!');
  } catch (err) {
    if (err.code === 'ER_DUP_FIELDNAME') {
      console.log('Columns already exist.');
    } else {
      console.error('❌ Migration failed:', err);
    }
  } finally {
    await connection.end();
  }
}

runMigrations();
