import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/rents_colors.dart';

class CreateBookingScreen extends StatefulWidget {
  final Map<String, dynamic>? bookingToEdit;
  const CreateBookingScreen({super.key, this.bookingToEdit});

  @override
  State<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends State<CreateBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _discountController = TextEditingController();
  final _notesController = TextEditingController();
  final _guestNameController = TextEditingController();
  final _guestPhoneController = TextEditingController();

  List<dynamic> _rooms = [];
  List<dynamic> _students = [];
  List<dynamic> _allBookings = [];

  String? _selectedRoomId;
  String? _selectedStudentId;
  String _customerType = 'student';
  String _discountType = 'percent';

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  bool _isLoadingData = true;
  bool _isSaving = false;

  bool get _isGuestBooking => _customerType == 'guest';

  Map<String, dynamic>? get _selectedRoom {
    for (final room in _rooms) {
      if (room['id']?.toString() == _selectedRoomId) {
        return room as Map<String, dynamic>;
      }
    }
    return null;
  }

  double get _roomRate {
    final raw = _selectedRoom?['price_per_hour'];
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? 0;
  }

  int get _durationMinutes {
    final startMinutes = _startTime.hour * 60 + _startTime.minute;
    final endMinutes = _endTime.hour * 60 + _endTime.minute;
    return endMinutes > startMinutes ? endMinutes - startMinutes : 0;
  }

  double get _durationHours => _durationMinutes / 60;

  double get _basePrice => _roomRate * _durationHours;

  double get _discountInputValue =>
      double.tryParse(_discountController.text.trim()) ?? 0;

  double get _discountAmount {
    final value = _discountInputValue;
    if (value <= 0 || _basePrice <= 0) return 0;

    if (_discountType == 'percent') {
      final percent = value.clamp(0, 100);
      return _basePrice * (percent / 100);
    }

    return value.clamp(0, _basePrice);
  }

  double get _finalPrice {
    final total = _basePrice - _discountAmount;
    return total < 0 ? 0 : total;
  }

  @override
  void initState() {
    super.initState();
    if (widget.bookingToEdit != null) {
      final b = widget.bookingToEdit!;
      _selectedRoomId = b['room_id']?.toString();
      _customerType = b['customer_type'] ?? 'student';
      if (_customerType == 'student') {
        _selectedStudentId = b['student_id']?.toString();
      } else {
        _guestNameController.text = b['guest_name'] ?? '';
        _guestPhoneController.text = b['guest_phone'] ?? '';
      }
      if (b['booking_date'] != null) {
        try {
          _selectedDate = DateTime.parse(b['booking_date']);
        } catch (_) {}
      }
      if (b['start_time'] != null) {
        final st = b['start_time'].toString().split(':');
        if (st.length >= 2) {
          _startTime = TimeOfDay(hour: int.parse(st[0]), minute: int.parse(st[1]));
        }
      }
      if (b['end_time'] != null) {
        final et = b['end_time'].toString().split(':');
        if (et.length >= 2) {
          _endTime = TimeOfDay(hour: int.parse(et[0]), minute: int.parse(et[1]));
        }
      }
      _discountType = b['discount_type'] ?? 'percent';
      _discountController.text = (b['discount_value'] ?? 0).toString();
      _notesController.text = b['notes'] ?? '';
    }
    _fetchData();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _notesController.dispose();
    _guestNameController.dispose();
    _guestPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final roomsRes = await ApiService.get('/rooms');
      final studentsRes = await ApiService.get('/students');
      final bookingsRes = await ApiService.get('/bookings');

      if (roomsRes.statusCode == 200 &&
          studentsRes.statusCode == 200 &&
          mounted) {
        final rooms = json.decode(roomsRes.body) as List<dynamic>;
        final students = json.decode(studentsRes.body) as List<dynamic>;
        final bookings = bookingsRes.statusCode == 200
            ? json.decode(bookingsRes.body) as List<dynamic>
            : [];
        setState(() {
          _rooms = rooms;
          _students = students;
          _allBookings = bookings;
          
          final availableRooms = _getAvailableRooms();
          if (widget.bookingToEdit == null) {
            _selectedRoomId = availableRooms.isNotEmpty
                ? availableRooms.first['id'].toString()
                : null;
            _selectedStudentId = _students.isNotEmpty
                ? _students.first['id'].toString()
                : null;
            if (_students.isEmpty) {
              _customerType = 'guest';
            }
          }
          _isLoadingData = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingData = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được phòng hoặc học viên')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _checkRoomAvailability();
      });
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _checkRoomAvailability();
      });
    }
  }

  void _checkRoomAvailability() {
    if (_selectedRoomId != null) {
      bool available = _isRoomAvailable(_selectedRoomId!);
      if (!available) {
        _selectedRoomId = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phòng này đã có người đặt trong khung giờ này')),
        );
      }
    }
  }

  bool _isRoomAvailable(String roomId) {
    final room = _rooms.firstWhere((r) => r['id'].toString() == roomId, orElse: () => null);
    if (room != null && room['status'] == 'maintenance') return false;

    final startMins = _startTime.hour * 60 + _startTime.minute;
    final endMins = _endTime.hour * 60 + _endTime.minute;
    if (endMins <= startMins) return true;

    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    for (final b in _allBookings) {
      if (widget.bookingToEdit != null && b['id'] == widget.bookingToEdit!['id']) continue;
      if (b['status'] == 'cancelled') continue;
      if (b['room_id'].toString() != roomId) continue;
      if (b['booking_date'] == null) continue;
      
      String bDate = b['booking_date'].toString();
      if (bDate.contains('T')) bDate = bDate.split('T')[0];
      if (bDate != dateStr) continue;

      final st = b['start_time'].toString().split(':');
      final et = b['end_time'].toString().split(':');
      if (st.length >= 2 && et.length >= 2) {
        final bStartMins = int.parse(st[0]) * 60 + int.parse(st[1]);
        final bEndMins = int.parse(et[0]) * 60 + int.parse(et[1]);

        // Trùng lịch nếu: start < bEnd && end > bStart
        if (startMins < bEndMins && endMins > bStartMins) {
          return false;
        }
      }
    }
    return true;
  }

  List<dynamic> _getAvailableRooms() {
    return _rooms.where((r) => _isRoomAvailable(r['id'].toString())).toList();
  }

  Future<void> _saveBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn phòng')));
      return;
    }
    if (!_isGuestBooking && _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn học viên hoặc chuyển sang Khách'),
        ),
      );
      return;
    }
    if (_durationMinutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giờ kết thúc phải sau giờ bắt đầu')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final body = {
        'room_id': int.parse(_selectedRoomId!),
        'student_id': _isGuestBooking ? null : int.parse(_selectedStudentId!),
        'customer_type': _customerType,
        'guest_name': _isGuestBooking ? _guestNameController.text.trim() : null,
        'guest_phone': _isGuestBooking
            ? _guestPhoneController.text.trim()
            : null,
        'booking_date':
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        'start_time':
            '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}:00',
        'end_time':
            '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}:00',
        'price': _finalPrice,
        'base_price': _basePrice,
        'discount_type': _discountType,
        'discount_value': _discountInputValue,
        'discount_amount': _discountAmount,
        'notes': _notesController.text.trim(),
      };

      final response = widget.bookingToEdit != null
          ? await ApiService.put('/bookings/${widget.bookingToEdit!['id']}', body)
          : await ApiService.post('/bookings', body);
          
      if ((response.statusCode == 200 || response.statusCode == 201) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.bookingToEdit != null ? 'Cập nhật thành công' : 'Tạo booking thành công'),
            backgroundColor: RentsColors.accentGreen,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        String message = 'Có lỗi xảy ra';
        try {
          final data = json.decode(response.body);
          message = data['message'] ?? message;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: RentsColors.accentRed,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi kết nối server'),
            backgroundColor: RentsColors.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        appBar: AppBar(
        centerTitle: true,title: const Text('THÊM LỊCH TẬP')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: RentsColors.bgGray,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          (widget.bookingToEdit != null ? 'CHỈNH SỬA LỊCH TẬP' : 'THÊM LỊCH TẬP').toUpperCase(),
          style: const TextStyle(
            color: RentsColors.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: RentsColors.primaryBlue),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Chọn Phòng/Studio',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildDropdown(
                value: _selectedRoomId,
                items: _rooms.map((room) {
                  final rId = room['id'].toString();
                  final isAvailable = _isRoomAvailable(rId);
                  return DropdownMenuItem<String>(
                    value: isAvailable ? rId : rId + '_disabled',
                    enabled: isAvailable,
                    child: Text(
                      isAvailable ? (room['name'] ?? 'Phòng') : (room['status'] == 'maintenance' ? '${room['name']} (Bảo trì)' : '${room['name']} (Trùng lịch)'),
                      style: TextStyle(
                        color: isAvailable ? Colors.black : Colors.grey,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && !value.endsWith('_disabled')) {
                    setState(() => _selectedRoomId = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Chọn Học viên/Khách',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _customerTypeButton('student', 'Học viên')),
                  const SizedBox(width: 12),
                  Expanded(child: _customerTypeButton('guest', 'Khách')),
                ],
              ),
              const SizedBox(height: 12),
              if (!_isGuestBooking)
                _buildDropdown(
                  value: _selectedStudentId,
                  items: _students
                      .map(
                        (student) => DropdownMenuItem<String>(
                          value: student['id'].toString(),
                          child: Text(student['name'] ?? 'Học viên'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _selectedStudentId = value),
                )
              else ...[
                TextFormField(
                  controller: _guestNameController,
                  validator: (value) {
                    if (_isGuestBooking &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Nhập tên khách';
                    }
                    return null;
                  },
                  decoration: _inputDecoration('Tên khách'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _guestPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Số điện thoại khách (nếu có)'),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Ngày tập',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: _pickerBox(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: RentsColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giờ bắt đầu',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectTime(true),
                          child: _pickerBox(
                            child: Center(
                              child: Text(
                                _startTime.format(context),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giờ kết thúc',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectTime(false),
                          child: _pickerBox(
                            child: Center(
                              child: Text(
                                _endTime.format(context),
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPricingSection(),
              const SizedBox(height: 20),
              const Text(
                'Ghi chú',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                maxLines: 4,
                decoration: _inputDecoration('Thông tin thêm'),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBooking,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RentsColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.bookingToEdit != null ? 'LƯU THAY ĐỔI' : 'TẠO BOOKING',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPricingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Giá cả', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                'Đơn giá phòng',
                '${_formatCurrency(_roomRate)}/gio',
              ),
              const SizedBox(height: 10),
              _buildSummaryRow('Thời lượng', _formatDuration(_durationMinutes)),
              const SizedBox(height: 10),
              _buildSummaryRow('Tạm tính', _formatCurrency(_basePrice)),
              const SizedBox(height: 16),
              const Text(
                'Discount',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _discountTypeButton('percent', 'Theo %')),
                  const SizedBox(width: 12),
                  Expanded(child: _discountTypeButton('amount', 'Theo giá')),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  final discount = double.tryParse(trimmed);
                  if (discount == null || discount < 0) {
                    return 'Giá trị discount không hợp lệ';
                  }
                  if (_discountType == 'percent' && discount > 100) {
                    return 'Discount % không được vượt quá 100';
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  _discountType == 'percent'
                      ? 'Nhập phần trăm discount'
                      : 'Nhập số tiền discount',
                ),
              ),
              const SizedBox(height: 14),
              _buildSummaryRow(
                'Giảm giá',
                '- ${_formatCurrency(_discountAmount)}',
              ),
              const Divider(height: 24),
              _buildSummaryRow(
                'Tổng tiền',
                _formatCurrency(_finalPrice),
                emphasize: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    final color = emphasize ? RentsColors.primaryBlue : RentsColors.black;
    final weight = emphasize ? FontWeight.w800 : FontWeight.w600;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: RentsColors.grayDark,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: weight,
            fontSize: emphasize ? 18 : 14,
          ),
        ),
      ],
    );
  }

  Widget _customerTypeButton(String value, String label) {
    final isSelected = _customerType == value;
    return GestureDetector(
      onTap: () => setState(() => _customerType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? RentsColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? RentsColors.primaryBlue : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : RentsColors.grayDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _discountTypeButton(String value, String label) {
    final isSelected = _discountType == value;
    return GestureDetector(
      onTap: () => setState(() => _discountType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? RentsColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? RentsColors.primaryBlue : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : RentsColors.grayDark,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _pickerBox({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes <= 0) return '0 giờ';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) return '$hours giờ';
    if (hours == 0) return '$minutes phút';
    return '$hours giờ $minutes phút';
  }

  String _formatCurrency(double value) {
    final rounded = value.round();
    final text = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final reverseIndex = text.length - i;
      buffer.write(text[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return '$buffer VND';
  }
}
