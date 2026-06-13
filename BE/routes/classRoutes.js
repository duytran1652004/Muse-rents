const express = require('express');
const router = express.Router();
const classController = require('../controllers/classController');
const auth = require('../middleware/auth');

router.get('/', auth, classController.getAllClasses);
router.get('/:id', auth, classController.getClassById);
router.post('/', auth, classController.createClass);
router.put('/:id', auth, classController.updateClass);
router.delete('/:id', auth, classController.deleteClass);
router.get('/:id/messages', auth, classController.getClassMessages);
router.post('/:id/messages', auth, classController.sendClassMessage);
router.delete('/:id/messages/:msgId', auth, classController.deleteClassMessage);

module.exports = router;
