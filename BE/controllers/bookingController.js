const db = require('../config/db');

function parseBookingMetadata(notes) {
  if (!notes || typeof notes !== 'string') {
    return { plainNotes: notes || '' };
  }

  try {
    const parsed = JSON.parse(notes);
    if (parsed && typeof parsed === 'object') {
        return {
          plainNotes: parsed.note || '',
          customerType: parsed.customerType,
          guestName: parsed.guestName,
          guestPhone: parsed.guestPhone,
          discountType: parsed.discountType,
          discountValue: parsed.discountValue,
          discountAmount: parsed.discountAmount,
          basePrice: parsed.basePrice,
          finalPrice: parsed.finalPrice,
        };
      }
    } catch (_) {
    // Keep backward compatibility with legacy plain-text notes.
  }

  return { plainNotes: notes };
}

function serializeBookingNotes({
  notes,
  customerType,
  guestName,
  guestPhone,
  discountType,
  discountValue,
  discountAmount,
  basePrice,
  finalPrice,
}) {
  const payload = {
    note: notes || '',
    customerType: customerType || (guestName ? 'guest' : 'student'),
    guestName: guestName || '',
    guestPhone: guestPhone || '',
    discountType: discountType || 'percent',
    discountValue: Number(discountValue || 0),
    discountAmount: Number(discountAmount || 0),
    basePrice: Number(basePrice || 0),
    finalPrice: Number(finalPrice || 0),
  };

  return JSON.stringify(payload);
}

function hydrateBookingRow(row) {
  const metadata = parseBookingMetadata(row.notes);
  const isGuestBooking = !row.student_id || metadata.customerType === 'guest';
  const guestName = metadata.guestName || null;
  const guestPhone = metadata.guestPhone || null;
  const customerName = isGuestBooking
    ? (guestName || row.student_name || 'Khach')
    : (row.student_name || 'N/A');

  const bookingDateLocal = row.booking_date instanceof Date
    ? `${row.booking_date.getFullYear()}-${String(row.booking_date.getMonth() + 1).padStart(2, '0')}-${String(row.booking_date.getDate()).padStart(2, '0')}`
    : row.booking_date;

  return {
    ...row,
    booking_date: bookingDateLocal,
    notes: metadata.plainNotes || '',
    customer_type: isGuestBooking ? 'guest' : 'student',
    guest_name: guestName,
    guest_phone: guestPhone,
    discount_type: metadata.discountType || 'percent',
    discount_value: Number(metadata.discountValue || 0),
    discount_amount: Number(metadata.discountAmount || 0),
    base_price: Number(metadata.basePrice || row.price || 0),
    final_price: Number(metadata.finalPrice || row.price || 0),
    customer_name: customerName,
    display_name: customerName,
  };
}

async function syncStudentStatus(studentId) {
  if (!studentId) return;

  const [students] = await db.query('SELECT status FROM students WHERE id = ?', [studentId]);
  if (students.length === 0) return;
  if (students[0].status === 'suspended') return;

  const [[bookingStats]] = await db.query(
    `SELECT COUNT(*) AS total
     FROM bookings
     WHERE student_id = ? AND status IN ('confirmed', 'completed')`,
    [studentId],
  );
  const [[enrollmentStats]] = await db.query(
    `SELECT COUNT(*) AS total
     FROM class_enrollments
     WHERE student_id = ? AND status = 'active'`,
    [studentId],
  );

  const nextStatus = (bookingStats.total > 0 || enrollmentStats.total > 0) ? 'active' : 'inactive';
  await db.query('UPDATE students SET status = ? WHERE id = ?', [nextStatus, studentId]);
}

exports.getAllBookings = async (req, res) => {
  try {
    const { room_id, student_id, search } = req.query;
    const where = [];
    const params = [];

    if (room_id) {
      where.push('b.room_id = ?');
      params.push(room_id);
    }
    if (student_id) {
      where.push('b.student_id = ?');
      params.push(student_id);
    }
    if (search) {
      where.push('(s.name LIKE ? OR r.name LIKE ? OR b.notes LIKE ?)');
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';

    const [rows] = await db.query(
      `SELECT b.*, s.name AS student_name, s.phone AS student_phone, r.name AS room_name, r.image_url AS room_image_url, r.facilities AS room_facilities, r.capacity AS room_capacity, u.full_name AS created_by_name
       FROM bookings b
       LEFT JOIN students s ON b.student_id = s.id
       LEFT JOIN rooms r ON b.room_id = r.id
       LEFT JOIN users u ON b.created_by = u.id
       ${whereClause}
       ORDER BY b.booking_date DESC, b.start_time DESC`,
      params,
    );

    res.json(rows.map(hydrateBookingRow));
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.createBooking = async (req, res) => {
  try {
    const {
      student_id,
      room_id,
      booking_date,
      start_time,
      end_time,
      price,
      notes,
      customer_type,
      guest_name,
      guest_phone,
      discount_type,
      discount_value,
      discount_amount,
      base_price,
    } = req.body;

    const bookingNotes = serializeBookingNotes({
      notes,
      customerType: customer_type,
      guestName: guest_name,
      guestPhone: guest_phone,
      discountType: discount_type,
      discountValue: discount_value,
      discountAmount: discount_amount,
      basePrice: base_price,
      finalPrice: price,
    });

    const [roomCheck] = await db.query('SELECT status FROM rooms WHERE id = ?', [room_id]);
    if (roomCheck.length > 0 && ['maintenance', 'closed'].includes(roomCheck[0].status)) {
      return res.status(400).json({ message: 'Phòng đang bảo trì hoặc đóng cửa, không thể đặt.' });
    }

    const [overlap] = await db.query(
      `SELECT id FROM bookings WHERE room_id = ? AND booking_date = ? AND status IN ('confirmed', 'in_progress') AND start_time < ? AND end_time > ?`,
      [room_id, booking_date, end_time, start_time]
    );
    if (overlap.length > 0) {
      return res.status(400).json({ message: 'Phòng đã có lịch đặt trong khoảng thời gian này.' });
    }

    const [overlapClass] = await db.query(
      `SELECT id FROM classes WHERE room_id = ? AND status = 'active' AND (
        (day_of_week = DAYNAME(?) AND start_time < ? AND end_time > ?) OR
        (day_of_week_2 = DAYNAME(?) AND start_time_2 < ? AND end_time_2 > ?) OR
        (day_of_week_3 = DAYNAME(?) AND start_time_3 < ? AND end_time_3 > ?)
      )`,
      [room_id, booking_date, end_time, start_time, booking_date, end_time, start_time, booking_date, end_time, start_time]
    );
    if (overlapClass.length > 0) {
      return res.status(400).json({ message: 'Phòng tập đã bị khóa vì có tiết Lớp học trong khoảng thời gian này.' });
    }

    const [result] = await db.query(
      `INSERT INTO bookings
       (student_id, room_id, booking_date, start_time, end_time, price, status, notes, created_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [student_id || null, room_id, booking_date, start_time, end_time, price || 0, 'confirmed', bookingNotes, req.user ? req.user.id : null],
    );

    if (student_id) {
      await syncStudentStatus(student_id);
    }

    // Insert notification
    try {
      await db.query(
        'INSERT INTO notifications (type, title, message, related_id) VALUES (?, ?, ?, ?)',
        ['booking', 'Lịch tập mới', 'Có một lịch tập mới vừa được tạo.', result.insertId]
      );
    } catch (notifErr) {
      console.error('Lỗi khi tạo thông báo:', notifErr);
    }

    res.status(201).json({ id: result.insertId, message: 'Booking created successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.updateBookingStatus = async (req, res) => {
  try {
    const [existingRows] = await db.query('SELECT * FROM bookings WHERE id = ?', [req.params.id]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    const existing = existingRows[0];
    const {
      status,
      notes,
      customer_type,
      guest_name,
      guest_phone,
      discount_type,
      discount_value,
      discount_amount,
      base_price,
      price,
      ...rest
    } = req.body;

    if (existing.status === 'completed') {
      if (status && status !== 'completed') {
        return res.status(400).json({ message: 'Lịch tập đã hoàn thành không thể đổi trạng thái.' });
      }
      if (price !== undefined || rest.start_time || rest.end_time || rest.room_id || rest.booking_date) {
        return res.status(400).json({ message: 'Không thể chỉnh sửa thời gian, phòng hoặc giá của lịch tập đã hoàn thành.' });
      }
    }

    if (existing.status === 'cancelled' && status === 'completed') {
      return res.status(400).json({ message: 'Không thể chuyển lịch đã hủy thành hoàn thành.' });
    }

    if (existing.status === 'in_progress' && status === 'cancelled') {
      return res.status(400).json({ message: 'Không thể hủy lịch đang sử dụng.' });
    }

    const checkRoomId = rest.room_id || existing.room_id;
    const checkDate = rest.booking_date || (existing.booking_date instanceof Date ? existing.booking_date.toISOString().split('T')[0] : existing.booking_date);
    const checkStart = rest.start_time || existing.start_time;
    const checkEnd = rest.end_time || existing.end_time;
    const checkStatus = status || existing.status;

    if (['confirmed', 'in_progress'].includes(checkStatus) && (rest.room_id || rest.booking_date || rest.start_time || rest.end_time || status === 'confirmed' || status === 'in_progress')) {
      const [overlap] = await db.query(
        `SELECT id FROM bookings WHERE room_id = ? AND booking_date = ? AND status IN ('confirmed', 'in_progress') AND start_time < ? AND end_time > ? AND id != ?`,
        [checkRoomId, checkDate, checkEnd, checkStart, existing.id]
      );
      if (overlap.length > 0) {
        return res.status(400).json({ message: 'Phòng đã có lịch đặt trong khoảng thời gian này.' });
      }

      const [overlapClass] = await db.query(
        `SELECT id FROM classes WHERE room_id = ? AND status = 'active' AND (
          (day_of_week = DAYNAME(?) AND start_time < ? AND end_time > ?) OR
          (day_of_week_2 = DAYNAME(?) AND start_time_2 < ? AND end_time_2 > ?) OR
          (day_of_week_3 = DAYNAME(?) AND start_time_3 < ? AND end_time_3 > ?)
        )`,
        [checkRoomId, checkDate, checkEnd, checkStart, checkDate, checkEnd, checkStart, checkDate, checkEnd, checkStart]
      );
      if (overlapClass.length > 0) {
        return res.status(400).json({ message: 'Phòng tập đã bị khóa vì có tiết Lớp học trong khoảng thời gian này.' });
      }
    }

    const fields = [];
    const params = [];

    if (status !== undefined) {
      fields.push('status = ?');
      params.push(status);
    }

    if (price !== undefined) {
      fields.push('price = ?');
      params.push(price);
    }

    Object.keys(rest).forEach((key) => {
      fields.push(`${key} = ?`);
      params.push(rest[key]);
    });

    if (
      notes !== undefined ||
      customer_type !== undefined ||
      guest_name !== undefined ||
      guest_phone !== undefined ||
      discount_type !== undefined ||
      discount_value !== undefined ||
      discount_amount !== undefined ||
      base_price !== undefined ||
      price !== undefined
    ) {
      const currentMeta = parseBookingMetadata(existing.notes);
      fields.push('notes = ?');
      params.push(serializeBookingNotes({
        notes: notes !== undefined ? notes : currentMeta.plainNotes,
        customerType: customer_type !== undefined ? customer_type : currentMeta.customerType,
        guestName: guest_name !== undefined ? guest_name : currentMeta.guestName,
        guestPhone: guest_phone !== undefined ? guest_phone : currentMeta.guestPhone,
        discountType: discount_type !== undefined ? discount_type : currentMeta.discountType,
        discountValue: discount_value !== undefined ? discount_value : currentMeta.discountValue,
        discountAmount: discount_amount !== undefined ? discount_amount : currentMeta.discountAmount,
        basePrice: base_price !== undefined ? base_price : currentMeta.basePrice,
        finalPrice: price !== undefined ? price : (currentMeta.finalPrice || existing.price),
      }));
    }

    if (fields.length === 0) {
      return res.status(400).json({ message: 'No fields to update' });
    }

    params.push(req.params.id);
    await db.query(`UPDATE bookings SET ${fields.join(', ')} WHERE id = ?`, params);

    if (existing.student_id) {
      await syncStudentStatus(existing.student_id);
    }
    if (rest.student_id && rest.student_id !== existing.student_id) {
      await syncStudentStatus(rest.student_id);
    }

    if (status !== undefined && status !== existing.status) {
      let statusStr = status;
      switch (status) {
        case 'confirmed': statusStr = 'Đã xác nhận'; break;
        case 'in_progress': statusStr = 'Đang sử dụng'; break;
        case 'completed': statusStr = 'Hoàn thành'; break;
        case 'cancelled': statusStr = 'Đã hủy'; break;
        case 'pending': statusStr = 'Chờ xác nhận'; break;
      }
      try {
        const [existingNotif] = await db.query('SELECT id FROM notifications WHERE type = ? AND related_id = ? LIMIT 1', ['booking', existing.id]);
        if (existingNotif.length > 0) {
          await db.query(
            'UPDATE notifications SET message = ?, is_read = 0, created_at = CURRENT_TIMESTAMP WHERE id = ?',
            [`Một lịch tập vừa được chuyển sang trạng thái: ${statusStr}.`, existingNotif[0].id]
          );
        } else {
          await db.query(
            'INSERT INTO notifications (type, title, message, related_id) VALUES (?, ?, ?, ?)',
            ['booking', 'Trạng thái thay đổi', `Một lịch tập vừa được chuyển sang trạng thái: ${statusStr}.`, existing.id]
          );
        }
      } catch (notifErr) {
        console.error('Lỗi khi tạo/cập nhật thông báo:', notifErr);
      }
    }

    res.json({ message: 'Booking updated successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};

exports.deleteBooking = async (req, res) => {
  try {
    const [existingRows] = await db.query('SELECT * FROM bookings WHERE id = ?', [req.params.id]);
    if (existingRows.length === 0) {
      return res.status(404).json({ message: 'Booking not found' });
    }

    if (['completed', 'in_progress'].includes(existingRows[0].status)) {
      return res.status(400).json({ message: 'Không thể xóa lịch tập đang sử dụng hoặc đã hoàn thành.' });
    }

    await db.query('DELETE FROM bookings WHERE id = ?', [req.params.id]);
    await db.query('DELETE FROM notifications WHERE related_id = ? AND type = ?', [req.params.id, 'booking']);

    if (existingRows[0].student_id) {
      await syncStudentStatus(existingRows[0].student_id);
    }

    res.json({ message: 'Booking deleted successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Server Error' });
  }
};
