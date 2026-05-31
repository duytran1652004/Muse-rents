const express = require('express');
const cors = require('cors');
const path = require('path');
const helmet = require('helmet');
const compression = require('compression');
require('dotenv').config();

const authRoutes = require('./routes/authRoutes');
const roomRoutes = require('./routes/roomRoutes');
const studentRoutes = require('./routes/studentRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const courseRoutes = require('./routes/courseRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const enrollmentRoutes = require('./routes/enrollmentRoutes');
const reportRoutes = require('./routes/reportRoutes');
const classRoutes = require('./routes/classRoutes');
const instructorRoutes = require('./routes/instructorRoutes');

const app = express();
const port = process.env.PORT || 3001;

app.use(helmet({ crossOriginResourcePolicy: false }));
app.use(compression());
app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.use('/api/auth', authRoutes);
app.use('/api/rooms', roomRoutes);
app.use('/api/students', studentRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/courses', courseRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/enrollments', enrollmentRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/classes', classRoutes);
app.use('/api/instructors', instructorRoutes);

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'MUSE Rents Backend is running' });
});

// Global Error Handler to prevent HTML error pages
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  if (err.name === 'MulterError' || err.message === 'Only images are allowed') {
    return res.status(400).json({ error: err.message });
  }
  res.status(500).json({ error: err.message || 'Internal Server Error' });
});

app.listen(port, () => {
  console.log('');
  console.log('=== MUSE Rents Backend ===');
  console.log('Status : RUNNING on port ' + port);
  console.log('Local  : http://localhost:' + port);
  console.log('==========================');
  console.log('');
});
