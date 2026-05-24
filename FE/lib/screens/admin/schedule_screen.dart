import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/booking_date_utils.dart';
import 'create_booking_screen.dart';
import 'notifications_screen.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String cleanText = newValue.text.replaceAll(',', '');
    int? value = int.tryParse(cleanText);
    if (value == null) return oldValue;
    String newText = cleanText.replaceAllMapped(
      RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'),
      (Match m) => '${m[1]},',
    );
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  Timer? _notificationTimer;
  int _unreadCount = 0;
  int? _lastNotificationId;

  // Search and Filter States
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus =
      'all'; // all, pending, confirmed, in_use, completed, cancelled
  DateTime? _filterDate;
  TimeOfDay? _filterStartTime;
  TimeOfDay? _filterEndTime;
  String _filterMinPrice = '';
  String _filterMaxPrice = '';

  @override
  void initState() {
    super.initState();
    _fetchBookings();
    _checkNewNotifications(isInit: true);
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkNewNotifications());
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/bookings');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _bookings = json.decode(response.body);
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkNewNotifications({bool isInit = false}) async {
    if (!mounted) return;
    try {
      final res = await ApiService.get('/notifications/unread-count');
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        int unread = data['count'] ?? 0;
        if (_unreadCount != unread) {
          setState(() => _unreadCount = unread);
        }
      }
    } catch (_) {}
  }

  List<dynamic> get _filteredBookings {
    return _bookings.where((b) {
      // 1. Search Query
      final query = _searchController.text.toLowerCase().trim();
      if (query.isNotEmpty) {
        final roomName = (b['room_name'] ?? '').toString().toLowerCase();
        final customerName =
            (b['display_name'] ?? b['student_name'] ?? b['guest_name'] ?? '')
                .toString()
                .toLowerCase();
        if (!roomName.contains(query) && !customerName.contains(query)) {
          return false;
        }
      } // 2. Status
      if (_filterStatus != 'all') {
        if (b['status'] != _filterStatus) return false;
      } // 3. Date
      if (_filterDate != null) {
        final bDate = parseBookingDate(b['booking_date']);
        if (bDate == null) return false;
        if (bDate.year != _filterDate!.year ||
            bDate.month != _filterDate!.month ||
            bDate.day != _filterDate!.day) {
          return false;
        }
      } // 4. Time range
      if (_filterStartTime != null || _filterEndTime != null) {
        final stStr = b['start_time']?.toString().split(':');
        final etStr = b['end_time']?.toString().split(':');
        if (stStr != null &&
            stStr.length >= 2 &&
            etStr != null &&
            etStr.length >= 2) {
          final bStartMins = int.parse(stStr[0]) * 60 + int.parse(stStr[1]);
          final bEndMins = int.parse(etStr[0]) * 60 + int.parse(etStr[1]);

          if (_filterStartTime != null) {
            final filterStartMins =
                _filterStartTime!.hour * 60 + _filterStartTime!.minute;
            if (bEndMins <= filterStartMins)
              return false; // Booking ends before filter start
          }
          if (_filterEndTime != null) {
            final filterEndMins =
                _filterEndTime!.hour * 60 + _filterEndTime!.minute;
            if (bStartMins >= filterEndMins)
              return false; // Booking starts after filter end
          }
        }
      } // 5. Price range
      final price = double.tryParse(b['price']?.toString() ?? '0') ?? 0;
      final minP = double.tryParse(_filterMinPrice.replaceAll(',', '')) ?? 0;
      final maxP =
          double.tryParse(_filterMaxPrice.replaceAll(',', '')) ??
          double.infinity;
      if (price < minP || price > maxP) return false;

      return true;
    }).toList();
  }

  Map<String, List<dynamic>> _groupBookings(List<dynamic> list) {
    final Map<String, List<dynamic>> map = {};
    for (var b in list) {
      final status = _getStatusLabel(b['status']);
      if (!map.containsKey(status)) {
        map[status] = [];
      }
      map[status]!.add(b);
    } // Sắp xếp các nhóm theo thứ tự ưu tiên nhất 9nh nếu mun
    return map;
  }

  void _showFilterSheet() {
    String tempStatus = _filterStatus;
    DateTime? tempDate = _filterDate;
    TimeOfDay? tempStartTime = _filterStartTime;
    TimeOfDay? tempEndTime = _filterEndTime;
    final minPriceCtrl = TextEditingController(text: _filterMinPrice);
    final maxPriceCtrl = TextEditingController(text: _filterMaxPrice);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle indicator
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: RentsColors.grayMedium,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lọc trạng thái',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFilterChipOption(
                                      'Tất cả',
                                      'all',
                                      tempStatus,
                                      RentsColors.primaryBlue,
                                      (val) =>
                                          setSheetState(() => tempStatus = val),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFilterChipOption(
                                      'Đã xác nhận',
                                      'confirmed',
                                      tempStatus,
                                      RentsColors.accentGreen,
                                      (val) =>
                                          setSheetState(() => tempStatus = val),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildFilterChipOption(
                                      'Đang sử dụng',
                                      'in_progress',
                                      tempStatus,
                                      RentsColors.accentOrange,
                                      (val) =>
                                          setSheetState(() => tempStatus = val),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildFilterChipOption(
                                      'Hoàn thành',
                                      'completed',
                                      tempStatus,
                                      RentsColors.primaryBlue,
                                      (val) =>
                                          setSheetState(() => tempStatus = val),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Lọc theo ngày',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: tempDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null)
                                setSheetState(() => tempDate = picked);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: RentsColors.grayLight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    tempDate != null
                                        ? '${tempDate!.day}/${tempDate!.month}/${tempDate!.year}'
                                        : 'Chọn ngày',
                                    style: TextStyle(
                                      color: tempDate != null
                                          ? RentsColors.black
                                          : Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (tempDate != null)
                                    GestureDetector(
                                      onTap: () =>
                                          setSheetState(() => tempDate = null),
                                      child: const Icon(
                                        Icons.close,
                                        size: 20,
                                        color: Colors.black87,
                                      ),
                                    )
                                  else
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 20,
                                      color: Colors.black87,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Khoảng thời gian',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          tempStartTime ??
                                          const TimeOfDay(hour: 8, minute: 0),
                                    );
                                    if (picked != null)
                                      setSheetState(
                                        () => tempStartTime = picked,
                                      );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: RentsColors.grayLight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          tempStartTime?.format(context) ??
                                              'Bắt đầu',
                                          style: TextStyle(
                                            color: tempStartTime != null
                                                ? RentsColors.black
                                                : Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (tempStartTime != null)
                                          GestureDetector(
                                            onTap: () => setSheetState(
                                              () => tempStartTime = null,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('-'),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          tempEndTime ??
                                          const TimeOfDay(hour: 22, minute: 0),
                                    );
                                    if (picked != null)
                                      setSheetState(() => tempEndTime = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: RentsColors.grayLight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          tempEndTime?.format(context) ??
                                              'Kết thúc',
                                          style: TextStyle(
                                            color: tempEndTime != null
                                                ? RentsColors.black
                                                : Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (tempEndTime != null)
                                          GestureDetector(
                                            onTap: () => setSheetState(
                                              () => tempEndTime = null,
                                            ),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Khoảng giá tiền',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: minPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    CurrencyInputFormatter(),
                                  ],
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Từ (VNĐ)',
                                    hintStyle: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: RentsColors.grayLight,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: RentsColors.grayLight,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: RentsColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('-'),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: maxPriceCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    CurrencyInputFormatter(),
                                  ],
                                  style: const TextStyle(fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Đến (VNĐ)',
                                    hintStyle: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: RentsColors.grayLight,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: RentsColors.grayLight,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: RentsColors.primaryBlue,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterStatus = 'all';
                              _filterDate = null;
                              _filterStartTime = null;
                              _filterEndTime = null;
                              _filterMinPrice = '';
                              _filterMaxPrice = '';
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: RentsColors.grayDark),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Xóa bộ lọc',
                            style: TextStyle(
                              color: RentsColors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _filterStatus = tempStatus;
                              _filterDate = tempDate;
                              _filterStartTime = tempStartTime;
                              _filterEndTime = tempEndTime;
                              _filterMinPrice = minPriceCtrl.text;
                              _filterMaxPrice = maxPriceCtrl.text;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RentsColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Áp dụng',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showBookingDetailSheet(Map<String, dynamic> booking) {
    final customerName =
        booking['display_name'] ??
        booking['student_name'] ??
        booking['guest_name'] ??
        'Khách';
    final roomName = booking['room_name'] ?? 'Phòng';
    final date = formatBookingDate(booking['booking_date']);
    final startTime = booking['start_time'] ?? '';
    final endTime = booking['end_time'] ?? '';
    final statusColor = _getStatusColor(booking['status']);
    final statusLabel = _getStatusLabel(booking['status']);
    final imageUrl = booking['room_image_url'];
    final finalPrice =
        double.tryParse(
          booking['final_price']?.toString() ??
              booking['price']?.toString() ??
              '0',
        ) ??
        0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: RentsColors.grayMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Room Image
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: RentsColors.bgGray,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          'http://10.0.2.2:3001$imageUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholderImage(),
                        ),
                      )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(height: 20),
              // Title and Edit
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      roomName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: RentsColors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreateBookingScreen(bookingToEdit: booking),
                        ),
                      );
                      if (result == true) _fetchBookings();
                    },
                    child: const Icon(
                      Icons.edit,
                      color: RentsColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Tags
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: RentsColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: RentsColors.primaryBlue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          customerName,
                          style: const TextStyle(
                            color: RentsColors.primaryBlue,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RentsColors.bgLightBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: RentsColors.primaryBlue.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.access_time_filled,
                            color: RentsColors.primaryBlue,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Thời gian',
                                style: TextStyle(
                                  color: RentsColors.grayDark,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$date | $startTime - $endTime',
                                style: const TextStyle(
                                  color: RentsColors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1, color: RentsColors.grayLight),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: RentsColors.accentGreen.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.payments,
                            color: RentsColors.accentGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Giá phòng',
                                style: TextStyle(
                                  color: RentsColors.grayDark,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatCurrency(finalPrice),
                                style: const TextStyle(
                                  color: RentsColors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Xác nhận',
                      RentsColors.accentGreen,
                      Colors.white,
                      () {
                        Navigator.pop(context);
                        _updateBookingStatus(booking['id'], 'confirmed');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'Đang sử dụng',
                      RentsColors.accentOrange,
                      Colors.white,
                      () {
                        Navigator.pop(context);
                        _updateBookingStatus(booking['id'], 'in_progress');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Hoàn thành',
                      RentsColors.primaryBlue,
                      Colors.white,
                      () {
                        Navigator.pop(context);
                        _updateBookingStatus(booking['id'], 'completed');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'Xóa',
                      Colors.white,
                      RentsColors.accentRed,
                      () {
                        Navigator.pop(context);
                        _deleteBooking(booking['id']);
                      },
                      isOutlined: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.meeting_room, size: 48, color: RentsColors.grayMedium),
        SizedBox(height: 8),
        Text(
          'Chưa có ảnh phòng',
          style: TextStyle(color: RentsColors.grayDark),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String label,
    Color bgColor,
    Color textColor,
    VoidCallback onTap, {
    bool isOutlined = false,
  }) {
    return SizedBox(
      height: 48,
      child: isOutlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: textColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }

  String _formatCurrency(double value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Future<void> _updateBookingStatus(dynamic id, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.put('/bookings/$id', {
        'status': newStatus,
      });
      if (response.statusCode == 200) {
        _fetchBookings();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi cập nhật trạng thái')),
          );
        }
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi kết nối server')));
      }
    }
  }

  Future<void> _deleteBooking(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa lịch tập này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.delete('/bookings/$id');
      if (response.statusCode == 200) {
        _fetchBookings();
      } else {
        setState(() => _isLoading = false);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Lỗi xóa lịch tập')));
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi kết nối server')));
    }
  }

  Widget _buildFilterChipOption(
    String label,
    String value,
    String currentValue,
    Color activeColor,
    Function(String) onSelect,
  ) {
    final isSelected = value == currentValue;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : RentsColors.bgGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : RentsColors.grayLight,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBookings;
    final grouped = _groupBookings(filtered);

    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'QUẢN LÝ LỊCH TẬP',
          style: TextStyle(
            color: RentsColors.black,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.filter_list_rounded,
              color: RentsColors.primaryBlue,
            ),
            onPressed: _showFilterSheet,
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              backgroundColor: RentsColors.accentGreen,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: RentsColors.primaryBlue,
              ),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              _checkNewNotifications();
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo tên phòng, khách hàng...',
                hintStyle: const TextStyle(
                  color: RentsColors.grayDark,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: RentsColors.grayDark,
                ),
                filled: true,
                fillColor: RentsColors.bgGray,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: RentsColors.primaryBlue,
                    width: 1,
                  ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                          color: RentsColors.grayDark,
                        ),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: RentsColors.primaryBlue,
                    ),
                  )
                : grouped.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy lịch tập nào',
                      style: TextStyle(color: RentsColors.grayDark),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, index) {
                      final statusKey = grouped.keys.elementAt(index);
                      final items = grouped[statusKey]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildGroupHeader(statusKey, items.length),
                          const SizedBox(height: 12),
                          ...items.map((b) => _buildBookingCard(b)),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: RentsColors.primaryBlue,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBookingScreen()),
          );
          if (result == true) {
            _fetchBookings();
            _checkNewNotifications();
          }
        },
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildGroupHeader(String title, int count) {
    Color indicatorColor = RentsColors.primaryBlue;
    if (title == 'Đang sử dụng' || title == 'Chờ xác nhận')
      indicatorColor = RentsColors.accentOrange;
    if (title == 'Đã xác nhận') indicatorColor = RentsColors.accentGreen;
    if (title == 'Đã hủy') indicatorColor = RentsColors.accentRed;

    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: indicatorColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: indicatorColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: indicatorColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: indicatorColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final customerName =
        booking['display_name'] ??
        booking['student_name'] ??
        booking['guest_name'] ??
        'Khách';
    final roomName = booking['room_name'] ?? 'Phòng';
    final date = formatBookingDate(booking['booking_date']);
    final startTime = booking['start_time'] ?? '';
    final endTime = booking['end_time'] ?? '';
    final statusColor = _getStatusColor(booking['status']);
    final statusLabel = _getStatusLabel(booking['status']);

    return GestureDetector(
      onTap: () => _showBookingDetailSheet(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: RentsColors.bgLightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: booking['room_image_url'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        'http://10.0.2.2:3001${booking['room_image_url']}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.meeting_room,
                          color: RentsColors.grayDark,
                        ),
                      ),
                    )
                  : const Icon(Icons.meeting_room, color: RentsColors.grayDark, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          roomName,
                          style: const TextStyle(
                            color: RentsColors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 16,
                        color: RentsColors.grayDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        customerName,
                        style: const TextStyle(
                          color: RentsColors.grayDark,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: RentsColors.grayDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$date | $startTime - $endTime',
                        style: const TextStyle(
                          color: RentsColors.grayDark,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return RentsColors.accentGreen;
      case 'in_progress':
        return RentsColors.accentOrange;
      case 'completed':
        return RentsColors.primaryBlue;
      case 'cancelled':
        return RentsColors.accentRed;
      case 'pending':
        return RentsColors.grayDark;
      default:
        return RentsColors.grayMedium;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'Đã xác nhận';
      case 'in_progress':
        return 'Đang sử dụng';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      case 'pending':
        return 'Chờ xác nhận';
      default:
        return status ?? 'Chờ xác nhận';
    }
  }
}
