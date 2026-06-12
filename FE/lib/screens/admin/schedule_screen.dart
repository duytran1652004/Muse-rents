import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/booking_date_utils.dart';
import '../../utils/globals.dart';
import '../../widgets/notification_button.dart';
import 'create_booking_screen.dart';
import 'notifications_screen.dart';
import 'edit_class_screen.dart';
import 'package:intl/intl.dart';

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
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
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

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _bookings = [];
  List<dynamic> _classesList = [];
  bool _isLoading = true;
  bool _isLoadingClasses = true;

  // Search and Filter States for Bookings
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, pending, confirmed, in_progress, completed, cancelled
  DateTime? _filterDate;
  TimeOfDay? _filterStartTime;
  TimeOfDay? _filterEndTime;
  String _filterMinPrice = '';
  String _filterMaxPrice = '';

  // Filter States for Classes
  String _filterClassStatus = 'all'; // all, active, completed, cancelled
  TimeOfDay? _filterClassStartTime;
  TimeOfDay? _filterClassEndTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _fetchBookings();
    _fetchClasses();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        fetchGlobalNotifications();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không kết nối được server, vui lòng thử lại! (Server có thể đang khởi động)')),
        );
      }
    }
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final response = await ApiService.get('/classes');
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _classesList = json.decode(response.body);
          _isLoadingClasses = false;
        });
        fetchGlobalNotifications();
      } else if (mounted) {
        setState(() => _isLoadingClasses = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClasses = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không kết nối được server, vui lòng thử lại! (Server có thể đang khởi động)')),
        );
      }
    }
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
                                    final picked = await showScrollTimePicker(
                                      context,
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
                                    final picked = await showScrollTimePicker(
                                      context,
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
    final startTime = formatTimeStr(booking['start_time']);
    final endTime = formatTimeStr(booking['end_time']);
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
                          ApiService.getImageUrl(imageUrl),
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
                  if (booking['status'] == 'confirmed' || booking['status'] == 'pending') ...[
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
                    if (booking['created_by_name'] != null) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1, color: RentsColors.grayLight),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: RentsColors.accentOrange.withValues(
                                alpha: 0.15,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: RentsColors.accentOrange,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Người tạo',
                                  style: TextStyle(
                                    color: RentsColors.grayDark,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  booking['created_by_name'].toString(),
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
                      (booking['status'] == 'completed' || booking['status'] == 'cancelled' || booking['status'] == 'in_progress') ? null : () {
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
                      (booking['status'] == 'completed' || booking['status'] == 'cancelled') ? null : () {
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
                      (booking['status'] == 'completed' || booking['status'] == 'cancelled') ? null : () {
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
                      (booking['status'] == 'completed' || booking['status'] == 'in_progress') ? null : () {
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
    VoidCallback? onTap, {
    bool isOutlined = false,
  }) {
    final isDisabled = onTap == null;
    return SizedBox(
      height: 48,
      child: isOutlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDisabled ? RentsColors.grayLight : textColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(color: isDisabled ? RentsColors.grayMedium : textColor, fontWeight: FontWeight.bold),
              ),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDisabled ? RentsColors.grayLight : bgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(color: isDisabled ? RentsColors.grayMedium : textColor, fontWeight: FontWeight.bold),
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
    return ValueListenableBuilder<String>(
      valueListenable: globalRole,
      builder: (context, role, child) {
        final filtered = _filteredBookings;
        final grouped = _groupBookings(filtered);
        final isTeacher = role == 'teacher';
        final isStudent = role == 'student';
        final isTeacherOrStudent = isTeacher || isStudent;
        final isStaff = role == 'user' || role == 'staff';

        return Scaffold(
          backgroundColor: RentsColors.bgLightBlue,
          appBar: AppBar(
            backgroundColor: RentsColors.bgLightBlue,
            elevation: 0,
            centerTitle: true,
            leading: const NotificationButton(),
            title: Text(
              isTeacherOrStudent ? 'LỚP HỌC' : 'QUẢN LÝ LỊCH TẬP',
              style: const TextStyle(
                color: RentsColors.black,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            actions: [
              if (!isTeacherOrStudent) ...[
                IconButton(
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    color: RentsColors.primaryBlue,
                  ),
                  onPressed: _tabController.index == 0 ? _showFilterSheet : _showClassFilterSheet,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
                onPressed: isTeacherOrStudent ? _fetchClasses : (_tabController.index == 0 ? _fetchBookings : _fetchClasses),
              ),
            ],
            bottom: isTeacherOrStudent ? null : TabBar(
              controller: _tabController,
              labelColor: RentsColors.primaryBlue,
              unselectedLabelColor: RentsColors.grayDark,
              indicatorColor: RentsColors.primaryBlue,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: const [
                Tab(text: 'Lịch tập'),
                Tab(text: 'Lớp học'),
              ],
            ),
          ),
          body: isTeacherOrStudent ? _buildClassesTab() : TabBarView(
            controller: _tabController,
            children: [
              _buildBookingsTab(grouped),
              _buildClassesTab(),
            ],
          ),
          floatingActionButton: isTeacherOrStudent ? null : FloatingActionButton(
            backgroundColor: RentsColors.primaryBlue,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onPressed: () async {
              if (_tabController.index == 0) {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateBookingScreen()),
                );
                if (result == true) {
                  _fetchBookings();
                }
              } else {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditClassScreen()),
                );
                if (result == true) {
                  _fetchClasses();
                }
              }
            },
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }

  Widget _buildBookingsTab(Map<String, List<dynamic>> grouped) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar
        Container(
          color: RentsColors.bgLightBlue,
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
              fillColor: Colors.white,
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
    );
  }

  void _showClassFilterSheet() {
    String tempStatus = _filterClassStatus;
    TimeOfDay? tempStartTime = _filterClassStartTime;
    TimeOfDay? tempEndTime = _filterClassEndTime;

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
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFilterChipOption(
                                  'Tất cả', 'all', tempStatus, RentsColors.primaryBlue,
                                  (val) => setSheetState(() => tempStatus = val),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFilterChipOption(
                                  'Đang học', 'active', tempStatus, RentsColors.accentGreen,
                                  (val) => setSheetState(() => tempStatus = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _buildFilterChipOption(
                                  'Hoàn thành', 'completed', tempStatus, RentsColors.primaryBlue,
                                  (val) => setSheetState(() => tempStatus = val),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildFilterChipOption(
                                  'Đã hủy', 'cancelled', tempStatus, RentsColors.accentRed,
                                  (val) => setSheetState(() => tempStatus = val),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Khoảng thời gian (Giờ học)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showScrollTimePicker(
                                      context,
                                      initialTime: tempStartTime ?? const TimeOfDay(hour: 8, minute: 0),
                                    );
                                    if (picked != null) setSheetState(() => tempStartTime = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: RentsColors.grayLight),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          tempStartTime?.format(context) ?? 'Bắt đầu',
                                          style: TextStyle(
                                            color: tempStartTime != null ? RentsColors.black : Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (tempStartTime != null)
                                          GestureDetector(
                                            onTap: () => setSheetState(() => tempStartTime = null),
                                            child: const Icon(Icons.close, size: 16, color: Colors.black87),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('-')),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showScrollTimePicker(
                                      context,
                                      initialTime: tempEndTime ?? const TimeOfDay(hour: 22, minute: 0),
                                    );
                                    if (picked != null) setSheetState(() => tempEndTime = picked);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: RentsColors.grayLight),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          tempEndTime?.format(context) ?? 'Kết thúc',
                                          style: TextStyle(
                                            color: tempEndTime != null ? RentsColors.black : Colors.black87,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (tempEndTime != null)
                                          GestureDetector(
                                            onTap: () => setSheetState(() => tempEndTime = null),
                                            child: const Icon(Icons.close, size: 16, color: Colors.black87),
                                          ),
                                      ],
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _filterClassStatus = 'all';
                              _filterClassStartTime = null;
                              _filterClassEndTime = null;
                            });
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: RentsColors.grayDark),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Xóa bộ lọc',
                            style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _filterClassStatus = tempStatus;
                              _filterClassStartTime = tempStartTime;
                              _filterClassEndTime = tempEndTime;
                            });
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RentsColors.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'Áp dụng',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildClassesTab() {
    // Filter classes based on search
    final query = _searchController.text.toLowerCase().trim();
    final filteredClasses = _classesList.where((c) {
      if (query.isNotEmpty) {
        final className = (c['class_name'] ?? '').toString().toLowerCase();
        final courseName = (c['course_name'] ?? '').toString().toLowerCase();
        final instructorName = (c['instructor_name'] ?? '').toString().toLowerCase();
        if (!className.contains(query) && !courseName.contains(query) && !instructorName.contains(query)) {
          return false;
        }
      }

      if (_filterClassStatus != 'all') {
        if (c['status'] != _filterClassStatus) return false;
      }

      if (_filterClassStartTime != null || _filterClassEndTime != null) {
        bool matchesTime = false;
        for (int i = 1; i <= 3; i++) {
          String? start = i == 1 ? c['start_time'] : i == 2 ? c['start_time_2'] : c['start_time_3'];
          String? end = i == 1 ? c['end_time'] : i == 2 ? c['end_time_2'] : c['end_time_3'];
          
          if (start != null && end != null) {
            final stStr = start.split(':');
            final etStr = end.split(':');
            if (stStr.length >= 2 && etStr.length >= 2) {
              final cStartMins = int.parse(stStr[0]) * 60 + int.parse(stStr[1]);
              final cEndMins = int.parse(etStr[0]) * 60 + int.parse(etStr[1]);
              
              bool ok = true;
              if (_filterClassStartTime != null) {
                final filterStartMins = _filterClassStartTime!.hour * 60 + _filterClassStartTime!.minute;
                if (cEndMins <= filterStartMins) ok = false;
              }
              if (_filterClassEndTime != null) {
                final filterEndMins = _filterClassEndTime!.hour * 60 + _filterClassEndTime!.minute;
                if (cStartMins >= filterEndMins) ok = false;
              }
              
              if (ok) {
                matchesTime = true;
                break;
              }
            }
          }
        }
        if (!matchesTime) return false;
      }

      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Bar (shared UI but applies to classes here)
        Container(
          color: RentsColors.bgLightBlue,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên lớp, khóa học, giáo viên...',
              hintStyle: const TextStyle(
                color: RentsColors.grayDark,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: RentsColors.grayDark,
              ),
              filled: true,
              fillColor: Colors.white,
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
          child: _isLoadingClasses
              ? const Center(
                  child: CircularProgressIndicator(
                    color: RentsColors.primaryBlue,
                  ),
                )
              : filteredClasses.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy lớp học nào',
                    style: TextStyle(color: RentsColors.grayDark),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredClasses.length,
                  itemBuilder: (context, index) {
                    return _buildClassCard(filteredClasses[index]);
                  },
                ),
        ),
      ],
    );
  }

  String _formatClassSchedules(Map<String, dynamic> cls) {
    Map<String, List<String>> timeToDays = {};
    for (int i = 1; i <= 3; i++) {
      String? day = i == 1 ? cls['day_of_week'] : i == 2 ? cls['day_of_week_2'] : cls['day_of_week_3'];
      String? start = i == 1 ? cls['start_time'] : i == 2 ? cls['start_time_2'] : cls['start_time_3'];
      String? end = i == 1 ? cls['end_time'] : i == 2 ? cls['end_time_2'] : cls['end_time_3'];
      
      if (day != null && start != null && end != null) {
        String timeStr = '${formatTimeStr(start)}-${formatTimeStr(end)}';
        if (!timeToDays.containsKey(timeStr)) timeToDays[timeStr] = [];
        timeToDays[timeStr]!.add(_translateDay(day));
      }
    }
    
    if (timeToDays.isEmpty) return 'Chưa có lịch';
    
    List<String> parts = [];
    timeToDays.forEach((time, days) {
      parts.add('${days.join(', ')} $time');
    });
    return parts.join(' | ');
  }

  String _getClassStatus(Map<String, dynamic> cls) {
    final completed = cls['completed_sessions'] ?? 0;
    final total = cls['total_sessions'] ?? 0;
    if (total > 0 && completed >= total) {
      return 'Hoàn thành';
    }

    if (cls['status'] != 'active') {
      return cls['status'] == 'completed' ? 'Hoàn thành' : 'Tạm dừng';
    }
    
    final now = DateTime.now();
    final todayStr = DateFormat('EEEE').format(now);
    
    for (int i = 1; i <= 3; i++) {
      String? day = i == 1 ? cls['day_of_week'] : i == 2 ? cls['day_of_week_2'] : cls['day_of_week_3'];
      String? start = i == 1 ? cls['start_time'] : i == 2 ? cls['start_time_2'] : cls['start_time_3'];
      String? end = i == 1 ? cls['end_time'] : i == 2 ? cls['end_time_2'] : cls['end_time_3'];
      
      if (day == todayStr && start != null && end != null) {
        try {
          final startParts = start.split(':');
          final endParts = end.split(':');
          if (startParts.length >= 2 && endParts.length >= 2) {
            final startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
            final endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
            
            if (now.isAfter(startTime.subtract(const Duration(minutes: 30))) && now.isBefore(startTime)) {
              return 'Sắp tới giờ học';
            }
            if (now.isAfter(startTime) && now.isBefore(endTime)) {
              return 'Đang diễn ra';
            }
          }
        } catch (_) {}
      }
    }
    return 'Đang học';
  }

  Color _getClassStatusColor(String statusLabel) {
    if (statusLabel == 'Đang diễn ra' || statusLabel == 'Sắp tới giờ học') return RentsColors.primaryBlue;
    if (statusLabel == 'Đang học') return RentsColors.accentGreen;
    if (statusLabel == 'Hoàn thành') return RentsColors.primaryBlue;
    return RentsColors.accentOrange;
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    final className = cls['class_name'] ?? 'Lớp học';
    final courseName = cls['course_name'] ?? 'Khóa học';
    final instructorName = cls['instructor_name'] ?? 'Chưa xếp giáo viên';
    
    final schedulesStr = _formatClassSchedules(cls);
    
    final statusLabel = _getClassStatus(cls);
    final statusColor = _getClassStatusColor(statusLabel);

    final completed = cls['completed_sessions'] ?? 0;
    final total = cls['total_sessions'] ?? 0;

    return GestureDetector(
      onTap: () => _showClassDetailSheet(cls),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: RentsColors.bgLightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: cls['course_image_url'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        ApiService.getImageUrl(cls['course_image_url']),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.school, color: RentsColors.grayDark, size: 30),
                      ),
                    )
                  : const Icon(Icons.school, color: RentsColors.grayDark, size: 30),
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
                          className,
                          style: const TextStyle(
                            color: RentsColors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.person_outline, size: 16, color: RentsColors.grayDark),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          instructorName,
                          style: const TextStyle(color: RentsColors.grayDark, fontSize: 15, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.access_time, size: 16, color: RentsColors.grayDark),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          schedulesStr,
                          style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.check_circle_outline, size: 16, color: RentsColors.grayDark),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Số buổi: $completed/$total',
                          style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

  void _showClassDetailSheet(Map<String, dynamic> cls) {
    final className = cls['class_name'] ?? 'Lớp học';
    final courseName = cls['course_name'] ?? 'Khóa học';
    final instructorName = cls['instructor_name'] ?? 'Chưa xếp giáo viên';
    
    final schedulesStr = _formatClassSchedules(cls);
    
    final statusLabel = _getClassStatus(cls);
    final statusColor = _getClassStatusColor(statusLabel);

    final completed = cls['completed_sessions'] ?? 0;
    final total = cls['total_sessions'] ?? 0;
    final imageUrl = cls['course_image_url'];
    final isTeacher = globalRole.value == 'teacher';
    final isStudent = globalRole.value == 'student';
    final isTeacherOrStudent = isTeacher || isStudent;
    final bool isInSession = cls['is_in_session'] == 1 || cls['is_in_session'] == true;
    
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
              // Image
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
                          ApiService.getImageUrl(imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                        ),
                      )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(height: 20),
              // Title & Edit
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      className,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: RentsColors.black),
                    ),
                  ),
                  if (!isTeacherOrStudent)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: RentsColors.primaryBlue),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditClassScreen(existingClass: cls)),
                        ).then((result) {
                          if (result == true) _fetchClasses();
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Tags
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: RentsColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(instructorName, style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: RentsColors.bgLightBlue, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.access_time_filled, color: RentsColors.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Thời gian', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(schedulesStr, style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: RentsColors.grayLight)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: RentsColors.accentGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle, color: RentsColors.accentGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tiến độ', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text('$completed / $total buổi', style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (cls['student_names'] != null && cls['student_names'].toString().isNotEmpty) ...[
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: RentsColors.grayLight)),
                      InkWell(
                        onTap: () {
                          _showStudentsListSheet(cls['students_json']);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
                                child: const Icon(Icons.group, color: RentsColors.primaryBlue, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Học viên (Nhấn để xem)', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(cls['student_names'].toString(), style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: RentsColors.grayMedium),
                            ],
                          ),
                        ),
                      ),
                    ],

                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Action Buttons
              if (!isStudent) ...[
                Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Tạm dừng',
                      RentsColors.accentOrange,
                      Colors.white,
                      cls['status'] == 'active' ? () {
                        Navigator.pop(context);
                        _updateClassStatus(cls['id'], 'cancelled');
                      } : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      'Mở lại',
                      RentsColors.accentGreen,
                      Colors.white,
                      cls['status'] == 'cancelled' ? () {
                        Navigator.pop(context);
                        _updateClassStatus(cls['id'], 'active');
                      } : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      isInSession ? 'Học xong' : 'Bắt đầu học',
                      isInSession ? RentsColors.primaryBlue : RentsColors.accentGreen,
                      Colors.white,
                      (cls['status'] == 'completed' || cls['status'] == 'cancelled' || (total > 0 && completed >= total)) ? null : () async {
                        if (!isInSession) {
                          // Bắt đầu học
                          if (context.mounted) Navigator.pop(context);
                          _updateClassSessionState(cls, true);
                        } else {
                          // Học xong
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Xác nhận'),
                              content: const Text('Xác nhận đã học xong buổi học này?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext, true),
                                  child: const Text('Xác nhận', style: TextStyle(color: RentsColors.primaryBlue)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            if (context.mounted) Navigator.pop(context);
                            _updateClassSessions(cls, completed + 1, isInSession: false);
                          }
                        }
                      },
                    ),
                  ),
                  if (!isTeacherOrStudent) const SizedBox(width: 12),
                  if (!isTeacherOrStudent)
                    Expanded(
                      child: _buildActionButton(
                        'Xóa',
                        Colors.white,
                        RentsColors.accentRed,
                        (cls['status'] == 'active') ? null : () {
                          Navigator.pop(context);
                          _deleteClass(cls['id']);
                        },
                        isOutlined: true,
                      ),
                    ),
                ],
              ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showStudentsListSheet(String? studentsJson) {
    if (studentsJson == null || studentsJson.isEmpty) return;
    
    List<dynamic> students = [];
    try {
      students = json.decode(studentsJson);
    } catch (_) {}

    if (students.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                  decoration: BoxDecoration(color: RentsColors.grayMedium, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text('Danh sách học viên', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: RentsColors.black)),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: students.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: RentsColors.grayLight),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: RentsColors.primaryBlue.withValues(alpha: 0.1),
                        child: const Icon(Icons.person, color: RentsColors.primaryBlue),
                      ),
                      title: Text(student['name']?.toString() ?? 'Học viên', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (student['phone'] != null && student['phone'].toString().isNotEmpty)
                            GestureDetector(
                              onTap: () async {
                                final phone = student['phone'].toString();
                                final Uri url = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(url)) {
                                  await launchUrl(url);
                                }
                              },
                              child: Text(student['phone'].toString(), style: const TextStyle(color: RentsColors.primaryBlue)),
                            ),
                          if (student['email'] != null && student['email'].toString().isNotEmpty)
                            Text(student['email'].toString(), style: const TextStyle(fontSize: 12)),
                          if (student['review'] != null && student['review'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                'Nhận xét: ${student['review']}',
                                style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic),
                              ),
                            )
                          ]
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.rate_review_outlined, color: RentsColors.primaryBlue),
                        tooltip: 'Nhận xét học viên',
                        onPressed: () => _showReviewDialog(student, (newReview) {
                          setModalState(() {
                            student['review'] = newReview;
                          });
                        }),
                      ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  void _showReviewDialog(Map<String, dynamic> student, Function(String) onSaved) {
    final TextEditingController reviewController = TextEditingController(text: student['review']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Nhận xét ${student['name']}'),
          content: TextField(
            controller: reviewController,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Nhập nhận xét...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final enrollmentId = student['enrollment_id'];
                if (enrollmentId == null) {
                  Navigator.pop(context);
                  return;
                }
                Navigator.pop(context);
                
                // Show updating state
                setState(() => _isLoadingClasses = true);
                
                try {
                  final response = await ApiService.put('/enrollments/$enrollmentId', {
                    'review': reviewController.text,
                  });
                  if (response.statusCode == 200) {
                    onSaved(reviewController.text);
                    _fetchClasses();
                  } else {
                    setState(() => _isLoadingClasses = false);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật nhận xét')));
                  }
                } catch (_) {
                  setState(() => _isLoadingClasses = false);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi hệ thống')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: RentsColors.primaryBlue),
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _updateClassStatus(dynamic id, String newStatus) async {
    setState(() => _isLoadingClasses = true);
    try {
      final response = await ApiService.put('/classes/$id', {'status': newStatus});
      if (response.statusCode == 200) {
        _fetchClasses();
      } else {
        setState(() => _isLoadingClasses = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật trạng thái')));
      }
    } catch (_) {
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _updateClassSessionState(Map<String, dynamic> cls, bool isInSession) async {
    setState(() => _isLoadingClasses = true);
    try {
      final response = await ApiService.put('/classes/${cls['id']}', {
        'is_in_session': isInSession,
      });
      if (response.statusCode == 200) {
        _fetchClasses();
      } else {
        setState(() => _isLoadingClasses = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật trạng thái lớp')));
      }
    } catch (_) {
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _updateClassSessions(Map<String, dynamic> cls, int newSessions, {bool? isInSession}) async {
    final total = cls['total_sessions'] ?? 0;
    String newStatus = cls['status'] ?? 'active';
    if (newSessions >= total && total > 0) {
      newStatus = 'completed';
    }

    setState(() => _isLoadingClasses = true);
    try {
      final body = <String, dynamic>{'completed_sessions': newSessions, 'status': newStatus};
      if (isInSession != null) body['is_in_session'] = isInSession;

      final response = await ApiService.put('/classes/${cls['id']}', body);
      if (response.statusCode == 200) {
        _fetchClasses();
      } else {
        setState(() => _isLoadingClasses = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật số buổi')));
      }
    } catch (_) {
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _deleteClass(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa lớp học này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoadingClasses = true);
    try {
      final response = await ApiService.delete('/classes/$id');
      if (response.statusCode == 200) {
        _fetchClasses();
      } else {
        setState(() => _isLoadingClasses = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể xóa lớp (đã hoàn thành hoặc lỗi hệ thống)')));
      }
    } catch (_) {
      setState(() => _isLoadingClasses = false);
    }
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
    final startTime = formatTimeStr(booking['start_time']);
    final endTime = formatTimeStr(booking['end_time']);
    final statusColor = _getStatusColor(booking['status']);
    final statusLabel = _getStatusLabel(booking['status']);

    return GestureDetector(
      onTap: () => _showBookingDetailSheet(booking),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: RentsColors.bgLightBlue,
                borderRadius: BorderRadius.circular(14),
              ),
              child: booking['room_image_url'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        ApiService.getImageUrl(booking['room_image_url']),
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
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
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
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.person_outline,
                          size: 16,
                          color: RentsColors.grayDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          customerName,
                          style: const TextStyle(
                            color: RentsColors.grayDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.access_time,
                          size: 16,
                          color: RentsColors.grayDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$date | $startTime - $endTime',
                          style: const TextStyle(
                            color: RentsColors.grayDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  if (booking['created_by_name'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.admin_panel_settings,
                            size: 16,
                            color: RentsColors.grayDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Người tạo: ${booking['created_by_name']}',
                            style: const TextStyle(
                              color: RentsColors.grayDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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

  String _translateDay(String? day) {
    if (day == null) return '';
    switch (day.toLowerCase()) {
      case 'monday': return 'Thứ Hai';
      case 'tuesday': return 'Thứ Ba';
      case 'wednesday': return 'Thứ Tư';
      case 'thursday': return 'Thứ Năm';
      case 'friday': return 'Thứ Sáu';
      case 'saturday': return 'Thứ Bảy';
      case 'sunday': return 'Chủ Nhật';
      default: return day;
    }
  }
}
