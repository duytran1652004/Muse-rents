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
    console.log('Running missing migrations on Aiven database...');

    // 1. Create class_messages table (just in case)
    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`class_messages\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
        \`class_id\` int(11) NOT NULL,
        \`sender_id\` int(11) NOT NULL,
        \`message\` text NOT NULL,
        \`created_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        KEY \`class_id\` (\`class_id\`),
        KEY \`sender_id\` (\`sender_id\`),
        CONSTRAINT \`class_messages_ibfk_1\` FOREIGN KEY (\`class_id\`) REFERENCES \`classes\` (\`id\`) ON DELETE CASCADE,
        CONSTRAINT \`class_messages_ibfk_2\` FOREIGN KEY (\`sender_id\`) REFERENCES \`users\` (\`id\`) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    `);
    console.log('- class_messages table verified');

    // 2. Add is_deleted column
    try {
      await connection.query('ALTER TABLE `class_messages` ADD COLUMN `is_deleted` TINYINT(1) NOT NULL DEFAULT 0;');
      console.log('- Added is_deleted column to class_messages');
    } catch (err) {
      if (err.code === 'ER_DUP_FIELDNAME') {
        console.log('- is_deleted column already exists');
      } else {
        throw err;
      }
    }

    // 3. Create class_message_reactions table
    await connection.query(`
      CREATE TABLE IF NOT EXISTS \`class_message_reactions\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
        \`message_id\` int(11) NOT NULL,
        \`user_id\` int(11) NOT NULL,
        \`reaction\` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
        \`created_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        UNIQUE KEY \`unique_reaction\` (\`message_id\`, \`user_id\`),
        CONSTRAINT \`fk_msg_reaction\` FOREIGN KEY (\`message_id\`) REFERENCES \`class_messages\` (\`id\`) ON DELETE CASCADE,
        CONSTRAINT \`fk_user_reaction\` FOREIGN KEY (\`user_id\`) REFERENCES \`users\` (\`id\`) ON DELETE CASCADE
      ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    `);
    console.log('- class_message_reactions table verified');

    console.log('✅ All migrations completed successfully!');
  } catch (err) {
    console.error('❌ Migration failed:', err);
  } finally {
    await connection.end();
  }
}

runMigrations();
