import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/rents_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/booking_date_utils.dart';
import 'edit_item_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _bookings = [];
  List<dynamic> _enrollments = [];
  bool _isLoadingBookings = true;
  bool _isLoadingEnrollments = true;
  Map<String, dynamic> _studentData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _studentData = Map<String, dynamic>.from(widget.student);
    _fetchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final studentId = _studentData['id'];

    try {
      final bookRes = await ApiService.get('/bookings?student_id=$studentId');
      if (bookRes.statusCode == 200 && mounted) {
        setState(() {
          _bookings = json.decode(bookRes.body);
          _isLoadingBookings = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingBookings = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingBookings = false);
      }
    }

    try {
      final enrollRes = await ApiService.get(
        '/enrollments?student_id=$studentId',
      );
      if (enrollRes.statusCode == 200 && mounted) {
        setState(() {
          _enrollments = json.decode(enrollRes.body);
          _isLoadingEnrollments = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingEnrollments = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingEnrollments = false);
      }
    }
  }

  Future<void> _editStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditItemScreen(type: 'student', existingData: _studentData),
      ),
    );

    if (result == true) {
      try {
        final res = await ApiService.get('/students/${_studentData['id']}');
        if (res.statusCode == 200 && mounted) {
          setState(() => _studentData = json.decode(res.body));
          _fetchHistory(); // Refresh enrollment history too
        }
      } catch (_) {}
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final res = await ApiService.put('/students/${_studentData['id']}', {
        'status': newStatus,
        'name': _studentData['name'],
        'phone': _studentData['phone'],
        'email': _studentData['email'],
      });
      if (res.statusCode == 200 && mounted) {
        setState(() => _studentData['status'] = newStatus);
      }
    } catch (_) {}
  }

  void _showStatusPicker() {
    Widget buildStatusButton(String status) {
      final isSuspended = status == 'suspended';
      final color = _statusColor(status);
      return Expanded(
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            _updateStatus(status);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isSuspended ? Colors.white : color,
              borderRadius: BorderRadius.circular(12),
              border: isSuspended ? Border.all(color: color) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                color: isSuspended ? color : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'CẬP NHẬT TRẠNG THÁI',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: RentsColors.primaryBlue),
              ),
            ),
            Row(
              children: [
                buildStatusButton('confirmed'),
                const SizedBox(width: 12),
                buildStatusButton('active'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                buildStatusButton('inactive'),
                const SizedBox(width: 12),
                buildStatusButton('suspended'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = (_studentData['name'] ?? 'Không tên').toString();
    final String status = (_studentData['status'] ?? 'active').toString();
    final Color statusColor = _statusColor(status);
    final String statusLabel = _statusLabel(status);
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          name.toUpperCase(),
          style: const TextStyle(
            color: RentsColors.black,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: RentsColors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: RentsColors.primaryBlue),
            onPressed: _editStudent,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: RentsColors.primaryBlue,
          unselectedLabelColor: RentsColors.grayDark,
          indicatorColor: RentsColors.primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'HỒ SƠ'),
            Tab(text: 'LỊCH SỬ HỌC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildProfileTab(), _buildBookingsTab()],
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Combined Profile & Stats Header
        Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: RentsColors.primaryBlue.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            children: [
              // Avatar & Basic Info centered
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: RentsColors.primaryBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: RentsColors.primaryBlue.withValues(alpha: 0.2), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        _studentData['name']?.toString().isNotEmpty == true ? _studentData['name'][0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: RentsColors.primaryBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _studentData['name']?.toString() ?? '—',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: RentsColors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _showStatusPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(_studentData['status']).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _statusLabel(_studentData['status']),
                            style: TextStyle(
                              color: _statusColor(_studentData['status']),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit_rounded, size: 12, color: _statusColor(_studentData['status'])),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _infoCard('Thông tin cá nhân', [
          _infoRow(
            Icons.phone_iphone_rounded,
            'Số điện thoại',
            _studentData['phone']?.toString() ?? '—',
            onTap: () async {
              final phone = _studentData['phone']?.toString() ?? '';
              if (phone.isNotEmpty && phone != '—') {
                final Uri url = Uri.parse('tel:$phone');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              }
            },
          ),
          _infoRow(
            Icons.email_outlined,
            'Email',
            _studentData['email']?.toString() ?? '—',
          ),
          _infoRow(
            Icons.event_note_rounded,
            'Ngày đăng ký',
            _formatDate(_studentData['enrollment_date']),
          ),
        ]),
        const SizedBox(height: 16),
        _buildCourseSection(),
      ],
    );
  }

  Widget _buildCourseSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.import_contacts_rounded, color: RentsColors.primaryBlue, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Khóa học tham gia',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: RentsColors.black,
                  ),
                ),
              ),
              Text(
                '${_enrollments.length} khóa',
                style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingEnrollments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: RentsColors.primaryBlue,
                ),
              ),
            )
          else if (_enrollments.isEmpty)
            _buildInlineEmptyState(
              'Chưa đăng ký khóa học nào',
              Icons.school_outlined,
            )
          else ...[
            ..._enrollments.map((enrollment) => _buildEnrollmentCard(enrollment)),
          ],
        ],
      ),
    );
  }

  Widget _buildEnrollmentCard(Map<String, dynamic> enrollment) {
    final String status = enrollment['status'] ?? 'active';
    final int completed = enrollment['completed_sessions'] ?? 0;
    final int total = enrollment['total_sessions'] ?? 0;
    
    final bool isCompleted = status == 'completed' || (total > 0 && completed >= total);
    final bool hasClass = enrollment['class_id'] != null;
    
    final String statusText = isCompleted ? 'Hoàn thành' : (status == 'active' || (status == 'confirmed' && hasClass)) ? 'Đang học' : status == 'confirmed' ? 'Đã xác nhận' : 'Đã hủy';
    final Color badgeColor = isCompleted ? RentsColors.primaryBlue : (status == 'active' || (status == 'confirmed' && hasClass)) ? RentsColors.accentGreen : status == 'confirmed' ? RentsColors.accentOrange : RentsColors.accentRed;

    final bool hasDetails = enrollment['day_of_week'] != null || enrollment['instructor_name'] != null || (enrollment['total_sessions'] != null && enrollment['total_sessions'] > 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: badgeColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: enrollment['course_image_url'] != null && enrollment['course_image_url'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            ApiService.getImageUrl(enrollment['course_image_url']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.school_outlined,
                              color: badgeColor,
                              size: 24,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.school_outlined,
                          color: badgeColor,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (enrollment['class_name'] ?? enrollment['course_name'] ?? 'Khóa học').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: RentsColors.black,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (statusText != 'Hoàn thành' && statusText != 'Đang học')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: RentsColors.accentRed, size: 20),
                    onPressed: () => _deleteEnrollment(enrollment['id']),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            if (hasDetails) ...[
              const Divider(height: 20, thickness: 0.5),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (enrollment['day_of_week'] != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(Icons.access_time, size: 14, color: RentsColors.grayDark),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _formatClassSchedules(enrollment),
                                  style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (enrollment['instructor_name'] != null) ...[
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 14, color: RentsColors.grayDark),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'GV: ${enrollment['instructor_name']}',
                                  style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (enrollment['total_sessions'] != null && enrollment['total_sessions'] > 0)
                          Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 14, color: RentsColors.grayDark),
                              const SizedBox(width: 6),
                              Text(
                                'Số buổi: ${enrollment['completed_sessions'] ?? 0}/${enrollment['total_sessions']}',
                                style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
      ),
    );
  }

  String _formatClassSchedules(Map<String, dynamic> cls) {
    List<String> schedules = [];
    void addSchedule(String? day, String? start, String? end) {
      if (day != null && start != null && end != null) {
        schedules.add('$day (${formatTimeStr(start)} - ${formatTimeStr(end)})');
      }
    }
    addSchedule(cls['day_of_week'], cls['start_time'], cls['end_time']);
    addSchedule(cls['day_of_week_2'], cls['start_time_2'], cls['end_time_2']);
    addSchedule(cls['day_of_week_3'], cls['start_time_3'], cls['end_time_3']);
    return schedules.join('\n');
  }


  Widget _infoCard(String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: RentsColors.black,
            ),
          ),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: RentsColors.primaryBlue),
            const SizedBox(width: 10),
            Text(
              '$label:',
              style: const TextStyle(color: RentsColors.grayDark, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: onTap != null && value != '—' ? RentsColors.primaryBlue : RentsColors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  decoration: onTap != null && value != '—' ? TextDecoration.underline : null,
                  decorationColor: RentsColors.primaryBlue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsTab() {
    if (_isLoadingBookings || _isLoadingEnrollments) {
      return const Center(
        child: CircularProgressIndicator(color: RentsColors.primaryBlue),
      );
    }

    if (_bookings.isEmpty && _enrollments.isEmpty) {
      return _buildEmptyState('Chưa có lịch sử học nào', Icons.event_busy);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_enrollments.isNotEmpty) ...[
          const Text('Khóa học tham gia', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          ..._enrollments.map((e) => _buildEnrollmentCard(e)),
          const SizedBox(height: 24),
        ],
        if (_bookings.isNotEmpty) ...[
          const Text('Phòng đã sử dụng', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          ..._bookings.map((b) => _buildBookingCard(b)),
        ],
      ],
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final Color statusColor = _bookingStatusColor(booking['status']?.toString());
    final String statusLabel = _bookingStatusLabel(booking['status']?.toString());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              statusLabel == 'Hoàn thành' ? Icons.check_circle_outline : Icons.event_available_outlined,
              color: statusColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (booking['room_name'] ?? 'N/A').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: RentsColors.black,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: RentsColors.grayDark),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDate(booking['booking_date'])} | ${formatTimeStr(booking['start_time'])}',
                      style: const TextStyle(
                        color: RentsColors.grayDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (booking['created_by_name'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 12, color: RentsColors.grayDark),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Người tạo: ${booking['created_by_name']}',
                          style: const TextStyle(
                            color: RentsColors.grayDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddEnrollmentSheet() async {
    List<dynamic> classes = [];
    bool loadingClasses = true;
    Map<String, dynamic>? selectedClass;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (loadingClasses) {
            ApiService.get('/classes').then((res) {
              if (res.statusCode == 200) {
                final data = json.decode(res.body);
                if (data is List && data.isNotEmpty) {
                  setSheetState(() {
                    classes = data;
                    loadingClasses = false;
                  });
                } else {
                  // Fallback to courses
                  ApiService.get('/courses').then((courseRes) {
                    if (courseRes.statusCode == 200) {
                      setSheetState(() {
                        classes = (json.decode(courseRes.body) as List).map((c) => {
                          ...c,
                          'class_name': c['name'],
                        }).toList();
                        loadingClasses = false;
                      });
                    } else {
                      setSheetState(() => loadingClasses = false);
                    }
                  });
                }
              }
            });
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đăng ký khóa học',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: RentsColors.black,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Chọn khóa học/lớp từ danh sách:',
                  style: TextStyle(fontSize: 14, color: RentsColors.grayDark),
                ),
                const SizedBox(height: 8),
                if (loadingClasses)
                  const Center(child: CircularProgressIndicator())
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: RentsColors.grayLight),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        hint: const Text('Chọn khóa học'),
                        value: selectedClass,
                        items: classes
                            .map(
                              (courseClass) => DropdownMenuItem(
                                value: courseClass as Map<String, dynamic>,
                                child: Text(
                                  (courseClass['class_name'] ?? 'Lớp học')
                                      .toString(),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setSheetState(() => selectedClass = value),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (selectedClass != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: RentsColors.primaryBlue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: RentsColors.primaryBlue.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildPreviewRow(
                          Icons.payments,
                          'Học phí',
                          '${selectedClass!['price_per_class'] ?? selectedClass!['course_price'] ?? selectedClass!['price'] ?? 0}đ',
                        ),
                        const Divider(height: 24, thickness: 0.8),
                        _buildPreviewRow(
                          Icons.calendar_today,
                          'Lịch học',
                          '${selectedClass!['day_of_week'] ?? 'N/A'}',
                        ),
                        const Divider(height: 24, thickness: 0.8),
                        _buildPreviewRow(
                          Icons.access_time,
                          'Thời gian',
                          '${formatTimeStr(selectedClass!['start_time'])} - ${formatTimeStr(selectedClass!['end_time'])}',
                        ),
                        const Divider(height: 24, thickness: 0.8),
                        _buildPreviewRow(
                          Icons.timer,
                          'Thời hạn',
                          '${selectedClass!['duration'] ?? '1 tháng'}',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: selectedClass == null
                        ? null
                        : () async {
                            final isClass = selectedClass!.containsKey('course_id');
                            final res = await ApiService.post('/enrollments', {
                              'student_id': _studentData['id'],
                              if (isClass) 'class_id': selectedClass!['id'] else 'course_id': selectedClass!['id'],
                            });
                            if (res.statusCode == 201 || res.statusCode == 200) {
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _fetchHistory();
                              ApiService.get(
                                '/students/${_studentData['id']}',
                              ).then((studentRes) {
                                if (studentRes.statusCode == 200 && mounted) {
                                  setState(
                                    () => _studentData = json.decode(
                                      studentRes.body,
                                    ),
                                  );
                                }
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RentsColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'XÁC NHẬN ĐĂNG KÝ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPreviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: RentsColors.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: RentsColors.primaryBlue),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: RentsColors.grayDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: RentsColors.black,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteEnrollment(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('XÁC NHẬN'),
        content: const Text('Bạn có chắc muốn xóa đăng ký khóa học này?'),
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

    if (confirm == true) {
      final res = await ApiService.delete('/enrollments/$id');
      if (res.statusCode == 200) {
        _fetchHistory();
        ApiService.get('/students/${_studentData['id']}').then((studentRes) {
          if (studentRes.statusCode == 200 && mounted) {
            setState(() => _studentData = json.decode(studentRes.body));
          }
        });
      }
    }
  }

  Widget _buildInlineEmptyState(String msg, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: RentsColors.grayLight),
            const SizedBox(height: 12),
            Text(
              msg,
              style: const TextStyle(color: RentsColors.grayMedium, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: RentsColors.grayMedium),
          const SizedBox(height: 12),
          Text(
            msg,
            style: const TextStyle(color: RentsColors.grayDark, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'confirmed':
        return RentsColors.accentOrange;
      case 'active':
        return RentsColors.accentGreen;
      case 'inactive':
        return RentsColors.primaryBlue;
      case 'suspended':
        return RentsColors.accentRed;
      default:
        return RentsColors.grayDark;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'confirmed':
        return 'Đã xác nhận';
      case 'active':
        return 'Đang học';
      case 'inactive':
        return 'Đã xong';
      case 'suspended':
        return 'Tạm dừng';
      default:
        return status ?? '';
    }
  }

  Color _bookingStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return RentsColors.accentOrange;
      case 'confirmed':
        return RentsColors.accentGreen;
      case 'completed':
        return RentsColors.primaryBlue;
      case 'cancelled':
        return RentsColors.accentRed;
      default:
        return RentsColors.grayDark;
    }
  }

  String _bookingStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Chờ';
      case 'confirmed':
        return 'Xác nhận';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status ?? '';
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) {
      return '—';
    }
    final formatted = formatBookingDate(date);
    return formatted.isEmpty ? date.toString() : formatted;
  }

  double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0;
  }

  String _formatPrice(double price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M';
    }
    if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K';
    }
    return price.toStringAsFixed(0);
  }
}
