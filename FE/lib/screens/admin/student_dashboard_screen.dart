import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/notification_button.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  List<dynamic> _enrollments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEnrollments();
  }

  Future<void> _fetchEnrollments() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/enrollments');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _enrollments = json.decode(res.body);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString();
    if (s.isEmpty) return '—';
    try {
      final dt = DateTime.parse(s).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}  ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return s;
    }
  }

  Color _badgeColor(Map<String, dynamic> e) {
    final String status = e['status'] ?? 'active';
    final int completed = e['completed_sessions'] ?? 0;
    final int total = e['total_sessions'] ?? 0;
    final bool isDone = status == 'completed' || (total > 0 && completed >= total);
    if (isDone) return RentsColors.primaryBlue;
    if (status == 'active' || (status == 'confirmed' && e['class_id'] != null)) return RentsColors.accentGreen;
    if (status == 'confirmed') return RentsColors.accentOrange;
    return RentsColors.accentRed;
  }

  String _statusText(Map<String, dynamic> e) {
    final String status = e['status'] ?? 'active';
    final int completed = e['completed_sessions'] ?? 0;
    final int total = e['total_sessions'] ?? 0;
    final bool isDone = status == 'completed' || (total > 0 && completed >= total);
    if (isDone) return 'Hoàn thành';
    if (status == 'active' || (status == 'confirmed' && e['class_id'] != null)) return 'Đang học';
    if (status == 'confirmed') return 'Đã xác nhận';
    return 'Đã hủy';
  }

  String _buildScheduleStr(Map<String, dynamic> e) {
    final List<String> parts = [];
    for (int i = 1; i <= 3; i++) {
      final day = i == 1 ? e['day_of_week'] : i == 2 ? e['day_of_week_2'] : e['day_of_week_3'];
      final start = i == 1 ? e['start_time'] : i == 2 ? e['start_time_2'] : e['start_time_3'];
      final end = i == 1 ? e['end_time'] : i == 2 ? e['end_time_2'] : e['end_time_3'];
      if (day != null && start != null && end != null) {
        final s = start.toString().length >= 5 ? start.toString().substring(0, 5) : start.toString();
        final en = end.toString().length >= 5 ? end.toString().substring(0, 5) : end.toString();
        parts.add('$day  $s–$en');
      }
    }
    return parts.isEmpty ? 'Chưa có lịch' : parts.join('\n');
  }

  Widget _payBadge(String label, String status, {String? dateStr}) {
    final Color color = status == 'completed' ? RentsColors.accentGreen : RentsColors.accentOrange;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(status == 'completed' ? Icons.check_circle : Icons.pending, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          if (status == 'completed' && dateStr != null && dateStr != '—')
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 20),
              child: Text('Xác nhận: $dateStr',
                  style: const TextStyle(fontSize: 11, color: RentsColors.grayDark)),
            ),
        ],
      ),
    );
  }

  void _showEnrollmentDetail(Map<String, dynamic> enrollment) {
    final badgeColor = _badgeColor(enrollment);
    final statusText = _statusText(enrollment);
    final String courseName = (enrollment['class_name'] ?? enrollment['course_name'] ?? 'Khóa học').toString();
    final int completed = enrollment['completed_sessions'] ?? 0;
    final int total = enrollment['total_sessions'] ?? 0;
    final String? teacherReview = enrollment['review']?.toString();
    final String? myReview = enrollment['student_review']?.toString();
    final String completedDate = _formatDateTime(enrollment['end_date']);
    final String payDate1 = _formatDateTime(enrollment['payment_date_1']);
    final String payDate2 = _formatDateTime(enrollment['payment_date_2']);

    // Student review controller
    final reviewController = TextEditingController(text: myReview ?? '');
    bool isSavingReview = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> saveStudentReview() async {
            final text = reviewController.text.trim();
            setSheetState(() => isSavingReview = true);
            try {
              final res = await ApiService.put('/enrollments/${enrollment['id']}', {'student_review': text});
              if (res.statusCode == 200 && ctx.mounted) {
                // Update local data
                setState(() {
                  final idx = _enrollments.indexWhere((e) => e['id'] == enrollment['id']);
                  if (idx >= 0) _enrollments[idx]['student_review'] = text;
                });
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                    content: Text('Đã lưu nhận xét'),
                    backgroundColor: Color(0xFF2ECC71),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    margin: EdgeInsets.all(16),
                  ));
                  Navigator.pop(ctx);
                }
              }
            } catch (_) {}
            if (ctx.mounted) setSheetState(() => isSavingReview = false);
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 6),
                    width: 44, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                          child: enrollment['course_image_url'] != null && enrollment['course_image_url'].toString().isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    ApiService.getImageUrl(enrollment['course_image_url']),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.school_outlined, color: badgeColor, size: 26),
                                  ),
                                )
                              : Icon(Icons.school_outlined, color: badgeColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(courseName,
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: RentsColors.black),
                                  maxLines: 2),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(statusText,
                                    style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20, indent: 20, endIndent: 20),
                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thông tin lớp
                          _sectionTitle('Thông tin lớp học'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F8FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                if (enrollment['instructor_name'] != null)
                                  _infoRow(Icons.person_outline, 'Giáo viên', enrollment['instructor_name']),
                                if (total > 0)
                                  _infoRow(Icons.check_circle_outline, 'Tiến độ', '$completed / $total buổi'),
                                if (enrollment['room_name'] != null)
                                  _infoRow(Icons.meeting_room_outlined, 'Phòng học', enrollment['room_name']),
                                if (enrollment['day_of_week'] != null)
                                  _infoRow(Icons.access_time_outlined, 'Lịch học', _buildScheduleStr(enrollment)),
                                if (statusText == 'Hoàn thành')
                                  _infoRow(Icons.event_available_outlined, 'Hoàn thành', completedDate,
                                      color: RentsColors.primaryBlue),
                              ],
                            ),
                          ),

                          // Teacher review (read only if exists)
                          if (teacherReview != null && teacherReview.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _sectionTitle('Nhận xét của giáo viên'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F8FF),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: RentsColors.primaryBlue.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.format_quote, size: 18, color: RentsColors.primaryBlue),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(teacherReview,
                                        style: const TextStyle(fontSize: 14, color: RentsColors.black, height: 1.5)),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Student review input
                          const SizedBox(height: 16),
                          _sectionTitle('Nhận xét của bạn'),
                          const SizedBox(height: 10),
                          if (completed > 0) ...[
                            TextField(
                              controller: reviewController,
                              maxLines: 3,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Viết cảm nhận về khóa học này...',
                                hintStyle: TextStyle(color: RentsColors.grayDark.withValues(alpha: 0.6), fontSize: 13),
                                filled: true,
                                fillColor: const Color(0xFFF5F8FF),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton(
                                onPressed: isSavingReview ? null : saveStudentReview,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RentsColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: isSavingReview
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text('Lưu nhận xét', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              ),
                            ),
                          ] else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: RentsColors.bgLightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline, color: RentsColors.primaryBlue, size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Bạn có thể viết nhận xét sau khi tham gia ít nhất 1 buổi học.',
                                      style: TextStyle(fontSize: 13, color: RentsColors.grayDark),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Payment
                          const SizedBox(height: 16),
                          _sectionTitle('Trạng thái thanh toán'),
                          const SizedBox(height: 10),
                          if (enrollment['payment_type'] == '100%')
                            _payBadge('Thanh toán 100%', enrollment['payment_status_1'] ?? 'pending', dateStr: payDate1)
                          else if (enrollment['payment_type'] == '50%') ...[
                            _payBadge('Đợt 1 (50%)', enrollment['payment_status_1'] ?? 'pending', dateStr: payDate1),
                            _payBadge('Đợt 2 (50%)', enrollment['payment_status_2'] ?? 'pending', dateStr: payDate2),
                          ] else
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Text('Chưa có thông tin thanh toán',
                                  style: TextStyle(color: RentsColors.grayDark, fontSize: 13, fontStyle: FontStyle.italic)),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: RentsColors.primaryBlue, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: RentsColors.black)),
        ],
      );

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: RentsColors.primaryBlue),
            const SizedBox(width: 10),
            SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: RentsColors.grayDark))),
            Expanded(
              child: Text(value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? RentsColors.black)),
            ),
          ],
        ),
      );

  Widget _buildEnrollmentCard(Map<String, dynamic> enrollment) {
    final badgeColor = _badgeColor(enrollment);
    final statusText = _statusText(enrollment);
    final int completed = enrollment['completed_sessions'] ?? 0;
    final int total = enrollment['total_sessions'] ?? 0;

    return GestureDetector(
      onTap: () => _showEnrollmentDetail(enrollment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: RentsColors.softCardShadow,
          border: Border.all(color: badgeColor.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: enrollment['course_image_url'] != null && enrollment['course_image_url'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            ApiService.getImageUrl(enrollment['course_image_url']),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.school_outlined, color: badgeColor, size: 22),
                          ),
                        )
                      : Icon(Icons.school_outlined, color: badgeColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (enrollment['class_name'] ?? enrollment['course_name'] ?? 'Khóa học').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: RentsColors.black, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(statusText, style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: RentsColors.grayMedium, size: 20),
              ],
            ),
            const Divider(height: 20, thickness: 0.5),
            if (enrollment['instructor_name'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  const Icon(Icons.person_outline, size: 15, color: RentsColors.grayDark),
                  const SizedBox(width: 7),
                  Text('Giáo viên: ${enrollment['instructor_name']}',
                      style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                ]),
              ),
            if (total > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 15, color: RentsColors.grayDark),
                  const SizedBox(width: 7),
                  Text('Đã học: $completed/$total buổi',
                      style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                ]),
              ),
            const SizedBox(height: 4),
            const Text('Trạng thái thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: RentsColors.black)),
            if (enrollment['payment_type'] == '100%')
              _payBadge('Thanh toán 100%', enrollment['payment_status_1'] ?? 'pending')
            else if (enrollment['payment_type'] == '50%') ...[
              _payBadge('Đợt 1 (50%)', enrollment['payment_status_1'] ?? 'pending'),
              _payBadge('Đợt 2 (50%)', enrollment['payment_status_2'] ?? 'pending'),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: Text('Chưa có thông tin thanh toán',
                    style: TextStyle(color: RentsColors.grayDark, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        title: const Text('KHÓA HỌC CỦA TÔI',
            style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: RentsColors.bgLightBlue,
        elevation: 0,
        leading: const NotificationButton(),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue), onPressed: _fetchEnrollments),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
          : _enrollments.isEmpty
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.school_outlined, size: 72, color: RentsColors.grayMedium),
                    const SizedBox(height: 16),
                    Text('Bạn chưa đăng ký khóa học nào',
                        style: TextStyle(
                            color: RentsColors.grayDark.withValues(alpha: 0.8),
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _fetchEnrollments,
                  color: RentsColors.primaryBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _enrollments.length,
                    itemBuilder: (context, index) => _buildEnrollmentCard(_enrollments[index]),
                  ),
                ),
    );
  }
}
