import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../theme/rents_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/globals.dart';
import 'edit_item_screen.dart';
class InstructorDetailScreen extends StatefulWidget {
  final Map<String, dynamic> instructor;
  const InstructorDetailScreen({super.key, required this.instructor});

  @override
  State<InstructorDetailScreen> createState() => _InstructorDetailScreenState();
}

class _InstructorDetailScreenState extends State<InstructorDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _classes = [];
  bool _isLoadingClasses = true;
  Map<String, dynamic> _instructorData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _instructorData = Map<String, dynamic>.from(widget.instructor);
    _fetchHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHistory() async {
    final id = _instructorData['id'];
    try {
      final res = await ApiService.get('/classes?instructor_id=$id');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _classes = json.decode(res.body);
          _isLoadingClasses = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingClasses = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _editInstructor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditItemScreen(type: 'instructor', existingData: _instructorData),
      ),
    );

    if (result == true) {
      try {
        final res = await ApiService.get('/instructors/${_instructorData['id']}');
        if (res.statusCode == 200 && mounted) {
          setState(() => _instructorData = json.decode(res.body));
          _fetchHistory();
        }
      } catch (_) {}
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final res = await ApiService.put('/instructors/${_instructorData['id']}', {
        'status': newStatus,
        'name': _instructorData['name'],
        'phone': _instructorData['phone'],
        'email': _instructorData['email'],
      });
      if (res.statusCode == 200 && mounted) {
        setState(() => _instructorData['status'] = newStatus);
      }
    } catch (_) {}
  }

  void _showStatusPicker() {
    Widget buildStatusButton(String status) {
      final label = _statusLabel(status);
      final color = _statusColor(status);
      final isActive = _instructorData['status'] == status;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            if (!isActive) _updateStatus(status);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: isActive ? color : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: isActive ? null : Border.all(color: RentsColors.grayMedium),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : RentsColors.grayDark,
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
                buildStatusButton('active'),
                const SizedBox(width: 12),
                buildStatusButton('inactive'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = (_instructorData['name'] ?? 'Không tên').toString();
    
    return ValueListenableBuilder<String>(
      valueListenable: globalRole,
      builder: (context, role, child) {
        final isStudent = role == 'student';
        final canViewDetails = !isStudent;
        final canEdit = role == 'admin' || role == 'staff';
        
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
            actions: canEdit ? [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: RentsColors.primaryBlue),
                onPressed: _editInstructor,
              ),
            ] : null,
            bottom: canViewDetails ? TabBar(
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
                Tab(text: 'LỊCH SỬ DẠY'),
              ],
            ) : null,
          ),
          body: canViewDetails 
            ? TabBarView(
                controller: _tabController,
                children: [_buildProfileTab(canViewDetails, canEdit), _buildHistoryTab()],
              )
            : _buildProfileTab(canViewDetails, canEdit),
        );
      },
    );
  }

  Widget _buildProfileTab(bool canViewDetails, bool canEdit) {
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
                        _instructorData['name']?.toString().isNotEmpty == true ? _instructorData['name'][0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: RentsColors.primaryBlue),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _instructorData['name']?.toString() ?? '—',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: RentsColors.black),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: canEdit ? _showStatusPicker : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(_instructorData['status']).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _statusLabel(_instructorData['status']),
                            style: TextStyle(
                              color: _statusColor(_instructorData['status']),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (canEdit) const SizedBox(width: 4),
                          if (canEdit) Icon(Icons.edit_rounded, size: 12, color: _statusColor(_instructorData['status'])),
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
            _instructorData['phone']?.toString() ?? '—',
            onTap: () async {
              final phone = _instructorData['phone']?.toString() ?? '';
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
            _instructorData['email']?.toString() ?? '—',
          ),
          _infoRow(
            Icons.event_note_rounded,
            'Ngày đăng ký',
            _formatDate(_instructorData['created_at']),
          ),
          if (_instructorData['bio'] != null && _instructorData['bio'].toString().isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 0.5),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.description_outlined, size: 18, color: RentsColors.primaryBlue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kinh nghiệm / Giới thiệu', style: TextStyle(color: RentsColors.grayDark, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        _instructorData['bio'].toString(),
                        style: const TextStyle(color: RentsColors.black, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ]),
        const SizedBox(height: 16),
        if (canViewDetails) _buildActiveClassesSection(),
      ],
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: RentsColors.black)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: RentsColors.primaryBlue),
            const SizedBox(width: 12),
            Text('$label: ', style: const TextStyle(color: RentsColors.grayDark, fontSize: 14)),
            Expanded(child: Text(value, style: TextStyle(color: onTap != null && value != '—' ? RentsColors.primaryBlue : RentsColors.black, fontSize: 14, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveClassesSection() {
    final activeClasses = _classes.where((c) => c['status'] == 'active').toList();
    
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
                  'Lớp học đang dạy',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: RentsColors.black,
                  ),
                ),
              ),
              Text(
                '${activeClasses.length} lớp',
                style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingClasses)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: RentsColors.primaryBlue,
                ),
              ),
            )
          else if (activeClasses.isEmpty)
            _buildInlineEmptyState(
              'Chưa có lớp học nào đang dạy',
              Icons.school_outlined,
            )
          else ...[
            ...activeClasses.map((c) => _buildClassCard(c, true)),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingClasses) {
      return const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue));
    }
    if (_classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.event_busy, size: 64, color: RentsColors.grayMedium),
            SizedBox(height: 16),
            Text('Chưa có lịch sử giảng dạy', style: TextStyle(color: RentsColors.grayDark)),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        return _buildClassCard(_classes[index], false);
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> c, bool isInline) {
    final status = c['status'] ?? 'active';
    final completed = c['completed_sessions'] ?? 0;
    final total = c['total_sessions'] ?? 0;
    
    final isCompleted = status == 'completed' || (total > 0 && completed >= total);
    
    final statusText = isCompleted ? 'Hoàn thành' : (status == 'active' ? 'Đang dạy' : 'Tạm dừng');
    final badgeColor = status == 'active' && !isCompleted ? RentsColors.accentGreen : isCompleted ? RentsColors.primaryBlue : RentsColors.accentOrange;
    
    final bool hasDetails = c['day_of_week'] != null || c['room_name'] != null || (c['total_sessions'] != null && c['total_sessions'] > 0);

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
        boxShadow: isInline ? null : RentsColors.softCardShadow,
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
                child: c['course_image_url'] != null && c['course_image_url'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          ApiService.getImageUrl(c['course_image_url']),
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
                      (c['class_name'] ?? 'Lớp học').toString(),
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
                      if (c['day_of_week'] != null) ...[
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
                                _formatClassSchedules(c),
                                style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (c['room_name'] != null) ...[
                        Row(
                          children: [
                            const Icon(Icons.meeting_room_outlined, size: 14, color: RentsColors.grayDark),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'P: ${c['room_name']}',
                                style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (c['total_sessions'] != null && c['total_sessions'] > 0)
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: RentsColors.grayDark),
                            const SizedBox(width: 6),
                            Text(
                              'Số buổi: ${c['completed_sessions'] ?? 0}/${c['total_sessions']}',
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
        schedules.add('$day (${start.substring(0, 5)} - ${end.substring(0, 5)})');
      }
    }
    addSchedule(cls['day_of_week'], cls['start_time'], cls['end_time']);
    addSchedule(cls['day_of_week_2'], cls['start_time_2'], cls['end_time_2']);
    addSchedule(cls['day_of_week_3'], cls['start_time_3'], cls['end_time_3']);
    return schedules.join('\n');
  }

  Widget _buildInlineEmptyState(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: RentsColors.bgGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: RentsColors.grayMedium.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: RentsColors.grayMedium),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
        ],
      ),
    );
  }

  Color _statusColor(String? s) {
    if (s == 'active') return RentsColors.accentGreen;
    return RentsColors.accentRed;
  }

  String _statusLabel(String? s) {
    if (s == 'active') return 'Đang dạy';
    return 'Nghỉ việc';
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return '--/--/----';
    try {
      final d = DateTime.parse(isoDate).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return isoDate;
    }
  }
}
