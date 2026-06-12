const express = require('express');
const router = express.Router();
const enrollmentController = require('../controllers/enrollmentController');
const auth = require('../middleware/auth');

router.get('/', auth, enrollmentController.getEnrollments);
router.post('/', auth, enrollmentController.createEnrollment);
router.put('/:id', auth, enrollmentController.updateEnrollment);
router.put('/:id/payment', auth, enrollmentController.updatePayment);
router.delete('/:id', auth, enrollmentController.deleteEnrollment);

module.exports = router;
