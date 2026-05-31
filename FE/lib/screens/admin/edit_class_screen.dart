import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class EditClassScreen extends StatefulWidget {
  final Map<String, dynamic>? course;
  final Map<String, dynamic>? existingClass;

  const EditClassScreen({super.key, this.course, this.existingClass});

  @override
  State<EditClassScreen> createState() => _EditClassScreenState();
}

class _EditClassScreenState extends State<EditClassScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maxStudentsController = TextEditingController(text: '4');
  final _priceController = TextEditingController(text: '0');
  final _totalSessionsController = TextEditingController(text: '0');

  List<dynamic> _rooms = [];
  List<dynamic> _instructors = [];
  List<dynamic> _courses = [];
  List<dynamic> _enrolledStudents = [];

  int? _selectedRoomId;
  int? _selectedInstructorId;
  int? _selectedCourseId;
  List<int> _selectedStudentIds = [];

  // Lịch 1
  String? _selectedDay;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // Lịch 2
  String? _selectedDay2;
  TimeOfDay? _startTime2;
  TimeOfDay? _endTime2;

  // Lịch 3
  String? _selectedDay3;
  TimeOfDay? _startTime3;
  TimeOfDay? _endTime3;

  bool _isLoading = false;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLookups();
  }

  void _initExistingClass() {
    if (widget.existingClass != null) {
      final c = widget.existingClass!;
      _selectedCourseId = c['course_id'];
      _maxStudentsController.text = (c['max_students'] ?? 4).toString();
      _priceController.text = NumberFormat('#,###').format(c['price_per_class'] ?? 0).replaceAll(',', '.');
      _totalSessionsController.text = (c['total_sessions'] ?? 0).toString();
      
      _selectedRoomId = c['room_id'];
      _selectedInstructorId = c['instructor_id'];

      // Lịch 1
      _selectedDay = c['day_of_week'];
      if (c['start_time'] != null) _startTime = _parseTime(c['start_time']);
      if (c['end_time'] != null) _endTime = _parseTime(c['end_time']);

      // Lịch 2
      _selectedDay2 = c['day_of_week_2'];
      if (c['start_time_2'] != null) _startTime2 = _parseTime(c['start_time_2']);
      if (c['end_time_2'] != null) _endTime2 = _parseTime(c['end_time_2']);

      // Lịch 3
      _selectedDay3 = c['day_of_week_3'];
      if (c['start_time_3'] != null) _startTime3 = _parseTime(c['start_time_3']);
      if (c['end_time_3'] != null) _endTime3 = _parseTime(c['end_time_3']);
      
      if (_selectedCourseId != null) {
        _fetchEnrolledStudents(_selectedCourseId!);
      }
    }
  }

  Future<void> _fetchEnrolledStudents(int courseId) async {
    try {
      final res = await ApiService.get('/enrollments?course_id=$courseId');
      if (res.statusCode == 200) {
        final enrollments = json.decode(res.body) as List;
        if (mounted) {
          setState(() {
            _enrolledStudents = enrollments.where((e) => e['status'] == 'confirmed' || e['status'] == 'active').toList();
            if (widget.existingClass != null) {
              final classId = widget.existingClass!['id'];
              _selectedStudentIds = _enrolledStudents
                .where((e) => e['class_id'] == classId)
                .map<int>((e) => e['student_id'] as int)
                .toList();
            } else {
              _selectedStudentIds = [];
            }
          });
        }
      }
    } catch (_) {}
  }

  TimeOfDay? _parseTime(dynamic timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.toString().split(':');
    if (parts.length >= 2) {
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    return null;
  }

  Future<void> _fetchLookups() async {
    try {
      final resRooms = await ApiService.get('/rooms');
      if (resRooms.statusCode == 200) {
        if (mounted) setState(() => _rooms = json.decode(resRooms.body));
      }
      final resInstructors = await ApiService.get('/instructors?status=active');
      if (resInstructors.statusCode == 200) {
        if (mounted) setState(() => _instructors = json.decode(resInstructors.body));
      }
      final resCourses = await ApiService.get('/courses');
      if (resCourses.statusCode == 200) {
        if (mounted) setState(() => _courses = json.decode(resCourses.body));
      }
      
      if (mounted) {
        _initExistingClass();
        setState(() {});
      }
    } catch (_) {}
  }

  void _onCourseSelected(int? courseId) {
    setState(() {
      _selectedCourseId = courseId;
      _enrolledStudents = [];
      _selectedStudentIds = [];
    });

    if (courseId != null) {
      _fetchEnrolledStudents(courseId);
      final course = _courses.firstWhere((c) => c['id'] == courseId, orElse: () => null);
      if (course != null) {
        final intPrice = (double.tryParse(course['price']?.toString() ?? '0') ?? 0).toInt();
        _priceController.text = NumberFormat('#,###').format(intPrice).replaceAll(',', '.');
        final duration = course['duration']?.toString() ?? '';
        final match = RegExp(r'\d+').firstMatch(duration);
        if (match != null) {
          _totalSessionsController.text = match.group(0) ?? '0';
        } else {
          _totalSessionsController.text = '0';
        }

        final cdjRoom = _rooms.firstWhere((r) => r['name'].toString().toLowerCase().contains('cdj 2000'), orElse: () => null);
        if (cdjRoom != null) {
          _selectedRoomId = cdjRoom['id'];
        }
      }
    }
  }

  Future<void> _pickTime(int scheduleIndex, bool isStart) async {
    TimeOfDay? initial;
    if (scheduleIndex == 1) initial = isStart ? _startTime : _endTime;
    if (scheduleIndex == 2) initial = isStart ? _startTime2 : _endTime2;
    if (scheduleIndex == 3) initial = isStart ? _startTime3 : _endTime3;

    final t = await showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
    );
    if (t != null) {
      setState(() {
        if (scheduleIndex == 1) {
          if (isStart) _startTime = t; else _endTime = t;
        } else if (scheduleIndex == 2) {
          if (isStart) _startTime2 = t; else _endTime2 = t;
        } else if (scheduleIndex == 3) {
          if (isStart) _startTime3 = t; else _endTime3 = t;
        }
      });
    }
  }

  String? _formatTimeStr(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn khóa học')));
      return;
    }
    
    bool hasAtLeastOneSchedule = (_selectedDay != null && _startTime != null && _endTime != null) ||
                                 (_selectedDay2 != null && _startTime2 != null && _endTime2 != null) ||
                                 (_selectedDay3 != null && _startTime3 != null && _endTime3 != null);

    if (!hasAtLeastOneSchedule) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin cho ít nhất 1 ô lịch học')));
      return;
    }

    setState(() => _isLoading = true);

    final course = _courses.firstWhere((c) => c['id'] == _selectedCourseId, orElse: () => null);
    final courseName = course != null ? course['name'] : 'Lớp học';

    final body = {
      'course_id': _selectedCourseId,
      'room_id': _selectedRoomId,
      'instructor_id': _selectedInstructorId,
      'class_name': courseName, // Tên lớp học mặc định theo tên khóa học
      
      'day_of_week': _selectedDay,
      'start_time': _formatTimeStr(_startTime),
      'end_time': _formatTimeStr(_endTime),

      'day_of_week_2': _selectedDay2,
      'start_time_2': _formatTimeStr(_startTime2),
      'end_time_2': _formatTimeStr(_endTime2),

      'day_of_week_3': _selectedDay3,
      'start_time_3': _formatTimeStr(_startTime3),
      'end_time_3': _formatTimeStr(_endTime3),

      'max_students': int.tryParse(_maxStudentsController.text) ?? 4,
      'price_per_class': double.tryParse(_priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0,
      'total_sessions': int.tryParse(_totalSessionsController.text) ?? 0,
      'status': 'active',
      'student_ids': _selectedStudentIds
    };

    try {
      final res = widget.existingClass == null
          ? await ApiService.post('/classes', body)
          : await ApiService.put('/classes/${widget.existingClass!['id']}', body);

      if (res.statusCode == 200 || res.statusCode == 201) {
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          final data = json.decode(res.body);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(data['message'] ?? 'Lỗi'),
              backgroundColor: RentsColors.accentRed));
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgGray,
      appBar: AppBar(
        title: Text(widget.existingClass == null ? 'THÊM LỚP HỌC' : 'SỬA LỚP HỌC',
            style: const TextStyle(
                color: RentsColors.primaryBlue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: RentsColors.primaryBlue),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildDropdown('Khóa học (Bắt buộc)', Icons.school, _courses, _selectedCourseId, _onCourseSelected),
              const SizedBox(height: 16),
              _buildDropdown('Giáo viên phụ trách', Icons.person, _instructors, _selectedInstructorId, (val) => setState(() => _selectedInstructorId = val)),
              const SizedBox(height: 16),
              _buildDropdown('Phòng học', Icons.meeting_room, _rooms, _selectedRoomId, (val) => setState(() => _selectedRoomId = val)),
              const SizedBox(height: 16),

              // Schedule 1
              _buildScheduleBlock(1, _selectedDay, _startTime, _endTime, 
                (v) => setState(() => _selectedDay = v),
                (isStart) => _pickTime(1, isStart)
              ),
              const SizedBox(height: 16),

              // Schedule 2
              _buildScheduleBlock(2, _selectedDay2, _startTime2, _endTime2, 
                (v) => setState(() => _selectedDay2 = v),
                (isStart) => _pickTime(2, isStart)
              ),
              const SizedBox(height: 16),

              // Schedule 3
              _buildScheduleBlock(3, _selectedDay3, _startTime3, _endTime3, 
                (v) => setState(() => _selectedDay3 = v),
                (isStart) => _pickTime(3, isStart)
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                      child: _buildInput(
                          controller: _maxStudentsController,
                          label: 'Sĩ số (Tối đa)',
                          icon: Icons.group,
                          keyboardType: TextInputType.number,
                          readOnly: true)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildInput(
                          controller: _priceController,
                          label: 'Giá/buổi',
                          icon: Icons.attach_money,
                          keyboardType: TextInputType.number,
                          readOnly: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildInput(
                  controller: _totalSessionsController,
                  label: 'Tổng số buổi',
                  icon: Icons.format_list_numbered,
                  keyboardType: TextInputType.number,
                  readOnly: true),
              
              const SizedBox(height: 16),
              _buildStudentSelection(),
              
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: RentsColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('LƯU LỚP HỌC',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleBlock(int index, String? day, TimeOfDay? start, TimeOfDay? end, Function(String?) onDayChanged, Function(bool) onTimePick) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LỊCH HỌC $index (Tùy chọn)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: RentsColors.primaryBlue)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Thứ trong tuần', border: OutlineInputBorder()),
            value: day,
            items: [
              const DropdownMenuItem(value: null, child: Text('Không chọn')),
              ..._days.map((d) => DropdownMenuItem(
                value: d, child: Text(_translateDay(d)))).toList(),
            ],
            onChanged: onDayChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onTimePick(true),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Giờ bắt đầu', border: OutlineInputBorder()),
                    child: Text(start?.format(context) ?? '--:--'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => onTimePick(false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Giờ kết thúc',
                        border: OutlineInputBorder()),
                    child: Text(end?.format(context) ?? '--:--'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInput(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      TextInputType keyboardType = TextInputType.text,
      bool readOnly = false,
      String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      style: readOnly ? const TextStyle(color: RentsColors.grayDark) : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: readOnly ? RentsColors.grayDark : RentsColors.primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
      ),
    );
  }

  Widget _buildDropdown(String label, IconData icon, List<dynamic> items,
      int? value, Function(int?) onChanged) {
    return DropdownButtonFormField<int>(
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: RentsColors.primaryBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        filled: true,
        fillColor: Colors.white,
      ),
      value: value,
      items: [
        const DropdownMenuItem(value: null, child: Text('Chưa chọn')),
        ...items.map((i) =>
            DropdownMenuItem(value: i['id'] as int, child: Text(i['name']))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildStudentSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HỌC VIÊN ĐÃ ĐĂNG KÝ (Tối đa 4)', style: TextStyle(fontWeight: FontWeight.bold, color: RentsColors.primaryBlue)),
          const SizedBox(height: 12),
          if (_selectedCourseId == null)
            const Text('Vui lòng chọn khóa học để hiển thị danh sách', style: TextStyle(color: RentsColors.grayDark, fontStyle: FontStyle.italic)),
          if (_selectedCourseId != null && _enrolledStudents.isEmpty)
            const Text('Chưa có học viên nào đăng ký khóa học này', style: TextStyle(color: RentsColors.grayDark, fontStyle: FontStyle.italic)),
          if (_selectedCourseId != null && _enrolledStudents.isNotEmpty)
            ..._enrolledStudents.map((e) {
              final studentId = e['student_id'] as int;
              final studentName = e['student_name'] ?? 'Học viên';
              final isSelected = _selectedStudentIds.contains(studentId);
              return CheckboxListTile(
                title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.w500)),
                value: isSelected,
                activeColor: RentsColors.primaryBlue,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      if (_selectedStudentIds.length < 4) {
                        _selectedStudentIds.add(studentId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chỉ có thể chọn tối đa 4 học viên')));
                      }
                    } else {
                      _selectedStudentIds.remove(studentId);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              );
            }).toList(),
        ],
      ),
    );
  }

  String _translateDay(String day) {
    switch (day) {
      case 'Monday':
        return 'Thứ Hai';
      case 'Tuesday':
        return 'Thứ Ba';
      case 'Wednesday':
        return 'Thứ Tư';
      case 'Thursday':
        return 'Thứ Năm';
      case 'Friday':
        return 'Thứ Sáu';
      case 'Saturday':
        return 'Thứ Bảy';
      case 'Sunday':
        return 'Chủ Nhật';
      default:
        return day;
    }
  }
}
