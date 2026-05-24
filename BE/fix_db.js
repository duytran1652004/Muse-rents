const db = require('./config/db');

async function fixDatabase() {
  try {
    console.log('Checking database schema...');

    // Add course_id to classes if it doesn't exist
    const [columns] = await db.query('SHOW COLUMNS FROM classes');
    const columnNames = columns.map(c => c.Field);

    if (!columnNames.includes('course_id')) {
      console.log('Adding course_id to classes table...');
      await db.query('ALTER TABLE classes ADD COLUMN course_id INT AFTER id');
      await db.query('ALTER TABLE classes ADD CONSTRAINT fk_course FOREIGN KEY (course_id) REFERENCES courses(id) ON DELETE CASCADE');
    }

    if (!columnNames.includes('room_id')) {
      console.log('Adding room_id to classes table...');
      await db.query('ALTER TABLE classes ADD COLUMN room_id INT AFTER course_id');
    }

    if (!columnNames.includes('instructor_id')) {
      console.log('Adding instructor_id to classes table...');
      await db.query('ALTER TABLE classes ADD COLUMN instructor_id INT AFTER room_id');
    }

    if (!columnNames.includes('price_per_class')) {
      console.log('Adding price_per_class to classes table...');
      await db.query('ALTER TABLE classes ADD COLUMN price_per_class DECIMAL(10, 2) AFTER max_students');
    }

    // Check class_enrollments
    const [enrollmentCols] = await db.query('SHOW COLUMNS FROM class_enrollments');
    const enrollmentColNames = enrollmentCols.map(c => c.Field);

    if (!enrollmentColNames.includes('start_date')) {
      console.log('Adding start_date to class_enrollments...');
      await db.query('ALTER TABLE class_enrollments ADD COLUMN start_date DATE AFTER student_id');
    }

    if (!enrollmentColNames.includes('end_date')) {
      console.log('Adding end_date to class_enrollments...');
      await db.query('ALTER TABLE class_enrollments ADD COLUMN end_date DATE AFTER start_date');
    }

    console.log('Database schema updated successfully!');
    process.exit(0);
  } catch (err) {
    console.error('Error fixing database:', err);
    process.exit(1);
  }
}

fixDatabase();
