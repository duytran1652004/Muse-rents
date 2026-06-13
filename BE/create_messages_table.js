const db = require('./config/db');

async function migrate() {
  try {
    await db.query(`
      CREATE TABLE IF NOT EXISTS class_messages (
        id INT AUTO_INCREMENT PRIMARY KEY,
        class_id INT NOT NULL,
        sender_id INT NOT NULL,
        message TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (class_id) REFERENCES classes(id) ON DELETE CASCADE,
        FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
      )
    `);
    console.log('Table class_messages created or already exists.');
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
}

migrate();
