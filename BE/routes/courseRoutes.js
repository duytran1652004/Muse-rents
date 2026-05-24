const express = require('express');
const router = express.Router();
const courseController = require('../controllers/courseController');
const upload = require('../middleware/upload');

router.get('/', courseController.getAllCourses);
router.get('/:id', courseController.getCourseById);
router.post('/', upload.single('image'), courseController.createCourse);
router.put('/:id', upload.single('image'), courseController.updateCourse);
router.delete('/:id', courseController.deleteCourse);

module.exports = router;
