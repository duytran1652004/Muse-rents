const express = require('express');
const router = express.Router();
const roomController = require('../controllers/roomController');
const upload = require('../middleware/upload');

router.get('/', roomController.getAllRooms);
router.get('/:id', roomController.getRoomById);
router.post('/', upload.single('image'), roomController.createRoom);
router.put('/:id', upload.single('image'), roomController.updateRoom);
router.delete('/:id', roomController.deleteRoom);

module.exports = router;
