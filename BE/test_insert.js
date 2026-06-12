const db = require('./config/db'); 
db.query("INSERT INTO class_enrollments (student_id, class_id, course_id, start_date, end_date, enrollment_date, status, created_by) VALUES (?, ?, ?, CURDATE(), DATE_ADD(CURDATE(), INTERVAL 1 MONTH), NOW(), 'confirmed', ?)", [1, null, 1, null]).then(() => { 
  console.log('success'); 
  process.exit(0); 
}).catch(e => { 
  console.log('ERROR:', e.message); 
  process.exit(0); 
});
