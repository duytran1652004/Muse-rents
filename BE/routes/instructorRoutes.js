const express = require('express');
const router = express.Router();
const instructorController = require('../controllers/instructorController');
const auth = require('../middleware/auth');

router.get('/', auth, instructorController.getAllInstructors);
router.get('/:id', auth, instructorController.getInstructorById);
router.post('/', auth, instructorController.createInstructor);
router.put('/:id', auth, instructorController.updateInstructor);
router.delete('/:id', auth, instructorController.deleteInstructor);

module.exports = router;
