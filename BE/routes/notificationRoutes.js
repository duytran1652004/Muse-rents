const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const auth = require('../middleware/auth');

router.use(auth);

router.get('/', notificationController.getAllNotifications);
router.get('/unread-count', notificationController.getUnreadCount);
router.post('/mark-all-read', notificationController.markAllRead);
router.post('/', notificationController.createNotification);
router.delete('/:id', notificationController.deleteNotification);
router.post('/delete-multiple', notificationController.deleteMultipleNotifications);

module.exports = router;
