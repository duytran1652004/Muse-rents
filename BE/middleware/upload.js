const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const fileFilter = (req, file, cb) => {
  const ext = path.extname(file.originalname).toLowerCase();
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'];
  
  if (file.mimetype.startsWith('image/') || allowedExtensions.includes(ext) || file.mimetype.includes('pdf') || file.mimetype.includes('document') || file.mimetype.includes('msword') || file.mimetype.includes('excel') || file.mimetype.includes('powerpoint')) {
    cb(null, true);
  } else {
    cb(new Error('Only images and documents are allowed (MIME: ' + file.mimetype + ')'), false);
  }
};

const upload = multer({ storage, fileFilter, limits: { fileSize: 20 * 1024 * 1024 } }); // Tăng giới hạn lên 20MB cho file

module.exports = upload;
