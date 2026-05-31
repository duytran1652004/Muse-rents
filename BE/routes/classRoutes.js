const express = require('express');
const router = express.Router();
const classController = require('../controllers/classController');
const auth = require('../middleware/auth');

router.get('/', auth, classController.getAllClasses);
router.get('/:id', auth, classController.getClassById);
router.post('/', auth, classController.createClass);
router.put('/:id', auth, classController.updateClass);
router.delete('/:id', auth, classController.deleteClass);

module.exports = router;
