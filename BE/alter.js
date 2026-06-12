const mysql = require('mysql2/promise');
require('dotenv').config();

async function run() {
  const conn = await mysql.createConnection({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    port: process.env.DB_PORT
  });
  
  try {
    await conn.query("ALTER TABLE users MODIFY COLUMN role VARCHAR(20) DEFAULT 'staff'");
    console.log("Modified role column to varchar");
  } catch (e) { console.log(e.message); }

  try {
    await conn.query("ALTER TABLE users ADD COLUMN status VARCHAR(20) DEFAULT 'active'");
    console.log("Added status column");
  } catch (e) { console.log(e.message); }

  conn.end();
}
run();
