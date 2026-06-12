const db = require('./config/db');

const recalculateStudentStatus = async (studentId) => {
  try {
    const [rows] = await db.query(
      'SELECT status FROM class_enrollments WHERE student_id = ?',
      [studentId]
    );
    
    let newStatus = 'inactive';
    if (rows.length > 0) {
      if (rows.some(r => r.status === 'active')) newStatus = 'active';
      else if (rows.some(r => r.status === 'confirmed')) newStatus = 'confirmed';
      else if (rows.every(r => r.status === 'completed')) newStatus = 'inactive';
      else if (rows.some(r => r.status === 'dropped')) newStatus = 'suspended';
      else newStatus = 'inactive';
    }
    
    await db.query('UPDATE students SET status = ? WHERE id = ?', [newStatus, studentId]);
  } catch (err) {
    console.error('Error updating student status:', err);
  }
};

async function test() {
  try {
    const student_id = 3; // Vũ Thị Hải
    const course_id = 1; // Khóa DJ chuyên nghiệp
    const class_id = undefined;

    let existingQuery = 'SELECT id FROM class_enrollments WHERE student_id = ? AND status = "active"';
    let existingParams = [student_id];
    
    if (class_id) {
      existingQuery += ' AND class_id = ?';
      existingParams.push(class_id);
    } else if (course_id) {
      existingQuery += ' AND course_id = ?';
      existingParams.push(course_id);
    } else {
      console.log('400 Error');
      process.exit(1);
    }

    const [existing] = await db.query(existingQuery, existingParams);

    if (existing.length > 0) {
      console.log('Already enrolled');
      process.exit(0);
    }

    const [result] = await db.query(
      'INSERT INTO class_enrollments (student_id, class_id, course_id, start_date, end_date, enrollment_date, status, created_by) VALUES (?, ?, ?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 MONTH), NOW(), "confirmed", ?)',
      [student_id, class_id || null, course_id || null, null]
    );
    
    await recalculateStudentStatus(student_id);
    console.log('success');
  } catch (err) {
    console.error('500 Error:', err);
  }
  process.exit(0);
}

test();
