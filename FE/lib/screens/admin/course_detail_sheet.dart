import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/booking_date_utils.dart';

class CourseDetailSheet extends StatefulWidget {
  final Map<String, dynamic> course;
  final String baseUrl;
  final VoidCallback onEdit;

  const CourseDetailSheet({
    super.key,
    required this.course,
    required this.baseUrl,
    required this.onEdit,
  });

  @override
  State<CourseDetailSheet> createState() => _CourseDetailSheetState();
}

class _CourseDetailSheetState extends State<CourseDetailSheet> {
  List<dynamic> _classes = [];
  List<dynamic> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final courseId = widget.course['id'];
      final futures = await Future.wait([
        ApiService.get('/classes?course_id=$courseId'),
        ApiService.get('/enrollments?course_id=$courseId'),
      ]);
      
      if (mounted) {
        setState(() {
          if (futures[0].statusCode == 200) {
            _classes = json.decode(futures[0].body) as List;
          }
          if (futures[1].statusCode == 200) {
            final allStudents = json.decode(futures[1].body) as List;
            _students = allStudents.where((s) {
              final status = (s['status'] ?? '').toString().toLowerCase();
              return status == 'active' || status == 'confirmed';
            }).toList();
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final imageUrl = course['image_url'];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RentsColors.grayMedium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AspectRatio(
                    aspectRatio: 2.0, // Make it half the height
                    child: (imageUrl != null && imageUrl.toString().isNotEmpty)
                      ? Image.network(
                          '${widget.baseUrl}$imageUrl',
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          course['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: RentsColors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: RentsColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Stats row
                  Row(
                    children: [
                      _statChip(
                        Icons.timer_outlined,
                        _courseDuration(course),
                        RentsColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        Icons.attach_money,
                        _formatPrice(course['price']),
                        RentsColors.accentGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  

                  const Text(
                    'Mô tả',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: RentsColors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (course['description'] ?? '').toString().isEmpty ? 'Chưa có mô tả' : course['description'],
                    style: const TextStyle(
                      color: RentsColors.grayDark,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 30),
                  Row(
                    children: [
                      const Text(
                        'Danh sách học viên',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: RentsColors.black,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _students.isNotEmpty
                              ? RentsColors.accentGreen.withValues(alpha: 0.12)
                              : RentsColors.accentOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _students.isNotEmpty
                              ? '${_students.length} học viên'
                              : 'Chưa có học viên',
                          style: TextStyle(
                            color: _students.isNotEmpty
                                ? RentsColors.accentGreen
                                : RentsColors.accentOrange,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_students.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RentsColors.bgLightBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.person_off_outlined,
                            color: RentsColors.accentOrange,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Chưa có học viên nào tham gia',
                            style: TextStyle(color: RentsColors.grayDark),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                      decoration: BoxDecoration(
                        color: RentsColors.bgLightBlue.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: RawScrollbar(
                        thumbColor: RentsColors.primaryBlue.withValues(alpha: 0.3),
                        radius: const Radius.circular(20),
                        thickness: 4,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          shrinkWrap: true,
                          itemCount: _students.length,
                          itemBuilder: (context, index) {
                            return _buildStudentCard(_students[index]);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      color: RentsColors.primaryBlue.withValues(alpha: 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: RentsColors.primaryBlue.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text(
            'Chưa có ảnh',
            style: TextStyle(
              color: RentsColors.primaryBlue.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RentsColors.bgLightBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RentsColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: RentsColors.primaryBlue.withValues(alpha: 0.12),
            child: const Icon(
              Icons.school_outlined,
              color: RentsColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls['class_name'] ?? 'Lớp học',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: RentsColors.black,
                  ),
                ),
                Text(
                  '${_translateDay(cls['day_of_week'])} | ${formatTimeStr(cls['start_time'])} - ${formatTimeStr(cls['end_time'])}',
                  style: const TextStyle(
                    color: RentsColors.grayDark,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Tối đa: ${cls['max_students'] ?? 0} học viên',
                  style: const TextStyle(
                    color: RentsColors.grayDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (cls['price_per_class'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: RentsColors.accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_formatPrice(cls['price_per_class'])}/buổi',
                style: const TextStyle(
                  color: RentsColors.accentGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
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

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }



  String _courseDuration(Map<String, dynamic> course) {
    final duration = (course['duration'] ?? '').toString().trim();
    return duration.isEmpty ? 'Chưa cập nhật' : '$duration buổi';
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final name = (student['student_name'] ?? 'Không rõ tên').toString();
    final date = student['enrollment_date'] != null 
        ? student['enrollment_date'].toString().split('T')[0] 
        : 'Chưa cập nhật';
    final status = (student['status'] ?? 'active').toString();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RentsColors.grayMedium.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: RentsColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: RentsColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: RentsColors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: RentsColors.grayDark),
                    const SizedBox(width: 4),
                    Text(
                      'Tham gia: $date',
                      style: const TextStyle(fontSize: 12, color: RentsColors.grayDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status == 'confirmed' ? RentsColors.primaryBlue.withValues(alpha: 0.1) : RentsColors.accentGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status == 'confirmed' ? 'Đã xác nhận' : 'Đang học',
              style: TextStyle(
                color: status == 'confirmed' ? RentsColors.primaryBlue : RentsColors.accentGreen,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num value = price is num
        ? price
        : num.tryParse(price.toString()) ?? 0;
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toString();
  }
}
