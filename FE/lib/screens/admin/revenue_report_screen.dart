import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/notification_button.dart';

class RevenueReportScreen extends StatefulWidget {
  const RevenueReportScreen({super.key});

  @override
  State<RevenueReportScreen> createState() => _RevenueReportScreenState();
}

class _RevenueReportScreenState extends State<RevenueReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Lịch tập state
  bool _isLoadingRoom = false;
  String _filterTypeRoom = 'month';
  DateTime _selectedDateRoom = DateTime.now();
  double _roomRevenue = 0;
  List<dynamic> _bookings = [];

  // Khóa học state
  bool _isLoadingCourse = false;
  String _filterTypeCourse = 'month';
  DateTime _selectedDateCourse = DateTime.now();
  double _courseRevenue = 0;
  int _courseRegistrations = 0;
  List<dynamic> _enrollments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRoomReport();
    _fetchCourseReport();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDateParam(String type, DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return type == 'day' ? '$year-$month-$day' : '$year-$month';
  }

  String _formatDisplayDate(String type, DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return type == 'day' ? '$day/$month/$year' : 'Tháng $month/$year';
  }

  Future<void> _fetchRoomReport() async {
    setState(() => _isLoadingRoom = true);
    try {
      final param = _formatDateParam(_filterTypeRoom, _selectedDateRoom);
      final res = await ApiService.get('/reports/revenue?type=$_filterTypeRoom&date=$param');
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        setState(() {
          _roomRevenue = (data['roomRevenue'] ?? 0).toDouble();
          _bookings = data['bookings'] ?? [];
          _isLoadingRoom = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingRoom = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRoom = false);
    }
  }

  Future<void> _fetchCourseReport() async {
    setState(() => _isLoadingCourse = true);
    try {
      final param = _formatDateParam(_filterTypeCourse, _selectedDateCourse);
      final res = await ApiService.get('/reports/revenue?type=$_filterTypeCourse&date=$param');
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        setState(() {
          _courseRevenue = (data['courseRevenue'] ?? 0).toDouble();
          _courseRegistrations = data['courseRegistrations'] ?? 0;
          _enrollments = data['enrollments'] ?? [];
          _isLoadingCourse = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingCourse = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCourse = false);
    }
  }

  Future<DateTime?> _showMonthPicker(BuildContext context, DateTime initialDate) async {
    DateTime tempDate = initialDate;
    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: RentsColors.primaryBlue),
                    onPressed: () {
                      setStateDialog(() => tempDate = DateTime(tempDate.year - 1, tempDate.month));
                    },
                  ),
                  Text(
                    'Năm ${tempDate.year}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: RentsColors.primaryBlue),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: RentsColors.primaryBlue),
                    onPressed: () {
                      setStateDialog(() => tempDate = DateTime(tempDate.year + 1, tempDate.month));
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                height: 280,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final isSelected = tempDate.year == initialDate.year && initialDate.month == month;
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context, DateTime(tempDate.year, month));
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? RentsColors.primaryBlue : RentsColors.bgLightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Tháng $month',
                          style: TextStyle(
                            color: isSelected ? Colors.white : RentsColors.black,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy', style: TextStyle(color: RentsColors.grayDark, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<DateTime?> _showDayPicker(BuildContext context, DateTime initialDate) async {
    return await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(12),
          content: SizedBox(
            width: 320,
            height: 320,
            child: CalendarDatePicker(
              initialDate: initialDate,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              onDateChanged: (DateTime date) {
                Navigator.pop(context, date);
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDate(bool isRoom) async {
    final currentFilter = isRoom ? _filterTypeRoom : _filterTypeCourse;
    final currentDate = isRoom ? _selectedDateRoom : _selectedDateCourse;

    DateTime? picked;

    if (currentFilter == 'day') {
      picked = await _showDayPicker(context, currentDate);
    } else {
      picked = await _showMonthPicker(context, currentDate);
    }

    if (picked != null) {
      setState(() {
        if (isRoom) {
          _selectedDateRoom = picked!;
        } else {
          _selectedDateCourse = picked!;
        }
      });
      if (isRoom) _fetchRoomReport(); else _fetchCourseReport();
    }
  }

  String _formatCurrency(double amount) {
    String value = amount.toStringAsFixed(0);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]}.';
    return '${value.replaceAllMapped(reg, mathFunc)} ₫';
  }

  String _formatDateOnly(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      return dateStr.split('T')[0];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: RentsColors.bgLightBlue,
        elevation: 0,
        leading: const NotificationButton(),
        title: const Text('BÁO CÁO DOANH THU', style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
            onPressed: () {
              _fetchRoomReport();
              _fetchCourseReport();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: RentsColors.primaryBlue,
          unselectedLabelColor: RentsColors.grayDark,
          indicatorColor: RentsColors.primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          tabs: const [
            Tab(text: 'LỊCH TẬP'),
            Tab(text: 'KHÓA HỌC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRoomTab(),
          _buildCourseTab(),
        ],
      ),
    );
  }

  Widget _buildFilterCard(bool isRoom) {
    final filterType = isRoom ? _filterTypeRoom : _filterTypeCourse;
    final date = isRoom ? _selectedDateRoom : _selectedDateCourse;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('Theo Ngày')),
                    ButtonSegment(value: 'month', label: Text('Theo Tháng')),
                  ],
                  selected: {filterType},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      if (isRoom) {
                        _filterTypeRoom = newSelection.first;
                      } else {
                        _filterTypeCourse = newSelection.first;
                      }
                    });
                    if (isRoom) _fetchRoomReport(); else _fetchCourseReport();
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: RentsColors.primaryBlue.withOpacity(0.1),
                    selectedForegroundColor: RentsColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _pickDate(isRoom),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                border: Border.all(color: RentsColors.grayLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: RentsColors.primaryBlue, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _formatDisplayDate(filterType, date),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_drop_down, color: RentsColors.grayMedium),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(amount),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTab() {
    return _isLoadingRoom
        ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
        : RefreshIndicator(
            onRefresh: _fetchRoomReport,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFilterCard(true),
                const SizedBox(height: 20),
                _buildTotalCard('DOANH THU PHÒNG TẬP', _roomRevenue, const Color(0xFF2ECC71)),
                const SizedBox(height: 24),
                const Text('Danh sách lịch thuê (Bảng doanh thu)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: RentsColors.primaryBlue)),
                const SizedBox(height: 12),
                if (_bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Không có dữ liệu', style: TextStyle(color: RentsColors.grayDark))),
                  )
                else
                  ..._bookings.map((b) => _buildBookingItem(b)),
              ],
            ),
          );
  }

  Widget _buildCourseTab() {
    return _isLoadingCourse
        ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
        : RefreshIndicator(
            onRefresh: _fetchCourseReport,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFilterCard(false),
                const SizedBox(height: 20),
                _buildTotalCard('DOANH THU KHÓA HỌC', _courseRevenue, const Color(0xFFFF6B35)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: RentsColors.grayLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, color: RentsColors.grayMedium, size: 20),
                      const SizedBox(width: 8),
                      Text('Tổng lượt đăng ký:', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: RentsColors.grayDark)),
                      const Spacer(),
                      Text('$_courseRegistrations lượt', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Danh sách đăng ký (Bảng doanh thu)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: RentsColors.primaryBlue)),
                const SizedBox(height: 12),
                if (_enrollments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('Không có dữ liệu', style: TextStyle(color: RentsColors.grayDark))),
                  )
                else
                  ..._enrollments.map((e) => _buildEnrollmentItem(e)),
              ],
            ),
          );
  }

  Widget _buildBookingItem(dynamic b) {
    String? guestName = b['student_name'];
    if (b['notes'] != null) {
      try {
        final notesObj = json.decode(b['notes']);
        if (notesObj['guestName'] != null && notesObj['guestName'].toString().isNotEmpty) {
          guestName = notesObj['guestName'];
        }
      } catch (_) {}
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: b['room_image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ApiService.getImageUrl(b['room_image_url']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.door_front_door_rounded, color: Color(0xFF2ECC71)),
                    ),
                  )
                : const Icon(Icons.door_front_door_rounded, color: Color(0xFF2ECC71)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b['room_name'] ?? 'Phòng trống', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Khách: ${guestName ?? 'Ẩn danh'}', style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                const SizedBox(height: 2),
                Text('${b['start_time']} - ${b['end_time']}', style: const TextStyle(color: RentsColors.grayMedium, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${_formatCurrency(double.tryParse(b['price']?.toString() ?? '0') ?? 0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2ECC71)),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateOnly(b['booking_date']),
                style: const TextStyle(color: RentsColors.black, fontSize: 13, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentItem(dynamic e) {
    String courseName = e['course_name'] ?? e['class_name'] ?? 'Khóa học';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: e['course_image_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ApiService.getImageUrl(e['course_image_url']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.library_books_rounded, color: Color(0xFFFF6B35)),
                    ),
                  )
                : const Icon(Icons.library_books_rounded, color: Color(0xFFFF6B35)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(courseName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('Học viên: ${e['student_name'] ?? 'Ẩn danh'}', style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${_formatCurrency(double.tryParse(e['paid_amount']?.toString() ?? e['price']?.toString() ?? '0') ?? 0)}',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFFFF6B35)),
              ),
              if (e['payment_phase'] != null) ...[
                const SizedBox(height: 2),
                Text(
                  e['payment_phase'],
                  style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                _formatDateOnly(e['enrollment_date']),
                style: const TextStyle(color: RentsColors.black, fontSize: 13, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ],
      ),
    );
  }
}
