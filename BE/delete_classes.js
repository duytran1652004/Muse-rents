const db = require('./config/db');
async function run() {
  try {
    const [classes] = await db.query("SELECT id FROM classes WHERE class_name LIKE '%DJ DÀNH CHO TRẺ%'");
    if (classes.length > 0) {
      const ids = classes.map(c => c.id);
      console.log('Deleting classes:', ids);
      await db.query("DELETE FROM class_enrollments WHERE class_id IN (?)", [ids]);
      await db.query("DELETE FROM classes WHERE id IN (?)", [ids]);
      console.log('Deleted.');
    } else {
      console.log('No classes found to delete.');
    }
  } catch (err) {
    console.error(err);
  }
  process.exit(0);
}
run();
