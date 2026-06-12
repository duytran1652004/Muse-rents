import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';

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

  Widget _buildPaymentBadge(String label, String status) {
    Color color;
    IconData icon;
    if (status == 'completed') {
      color = RentsColors.accentGreen;
      icon = Icons.check_circle;
    } else {
      color = RentsColors.accentOrange;
      icon = Icons.pending;
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
                          errorBuilder: (_, __, ___) => Icon(Icons.school_outlined, color: badgeColor, size: 24),
                        ),
                      )
                    : Icon(Icons.school_outlined, color: badgeColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (enrollment['class_name'] ?? enrollment['course_name'] ?? 'Khóa học').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: RentsColors.black, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(color: badgeColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          if (enrollment['instructor_name'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: RentsColors.grayDark),
                  const SizedBox(width: 8),
                  Text('Giáo viên: ${enrollment['instructor_name']}', style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                ],
              ),
            ),
          if (enrollment['total_sessions'] != null && enrollment['total_sessions'] > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: RentsColors.grayDark),
                  const SizedBox(width: 8),
                  Text('Đã học: ${enrollment['completed_sessions'] ?? 0}/${enrollment['total_sessions']} buổi', style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                ],
              ),
            ),
          
          // Thanh toán
          const SizedBox(height: 8),
          const Text('Trạng thái thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: RentsColors.black)),
          if (enrollment['payment_type'] == '100%') 
            _buildPaymentBadge('Thanh toán 100%', enrollment['payment_status_1'] ?? 'pending')
          else if (enrollment['payment_type'] == '50%') ...[
            _buildPaymentBadge('Đợt 1 (50%)', enrollment['payment_status_1'] ?? 'pending'),
            _buildPaymentBadge('Đợt 2 (50%)', enrollment['payment_status_2'] ?? 'pending'),
          ] else 
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Chưa có thông tin thanh toán', style: TextStyle(color: RentsColors.grayDark, fontSize: 13, fontStyle: FontStyle.italic)),
            )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        title: const Text('KHÓA HỌC CỦA TÔI', style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
            onPressed: _fetchEnrollments,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
          : _enrollments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.school_outlined, size: 80, color: RentsColors.grayMedium),
                      const SizedBox(height: 16),
                      Text('Bạn chưa đăng ký khóa học nào', style: TextStyle(color: RentsColors.grayDark.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchEnrollments,
                  color: RentsColors.primaryBlue,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _enrollments.length,
                    itemBuilder: (context, index) {
                      return _buildEnrollmentCard(_enrollments[index]);
                    },
                  ),
                ),
    );
  }
}
