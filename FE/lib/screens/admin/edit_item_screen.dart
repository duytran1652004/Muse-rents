import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';

class EditItemScreen extends StatefulWidget {
  final String type; // 'room', 'course', 'student'
  final Map<String, dynamic>? existingData; // null = create mode

  const EditItemScreen({super.key, required this.type, this.existingData});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  final _facilitiesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _durationController = TextEditingController();

  File? _imageFile;
  final _picker = ImagePicker();
  bool _isLoading = false;
  List<dynamic> _classes = [];
  final Set<String> _selectedIds = {};
  final Set<String> _initialSelectedIds = {};
  bool _isLoadingClasses = false;
  String _status = 'active';
  bool get _isEditMode => widget.existingData != null;

  static const String baseUrl = ApiService.serverUrl;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final d = widget.existingData!;
      _nameController.text = d['name'] ?? '';
      _descriptionController.text = d['description'] ?? '';
      
      final priceVal = (d['price'] ?? d['price_per_hour'] ?? '').toString();
      if (priceVal.isNotEmpty) {
        final doubleVal = double.tryParse(priceVal);
        if (doubleVal != null) {
          final number = doubleVal.toInt();
          _priceController.text = number.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
        } else {
          _priceController.text = priceVal;
        }
      }
      
      _capacityController.text = (d['capacity'] ?? '').toString();
      _facilitiesController.text = d['facilities'] ?? '';
      _phoneController.text = d['phone'] ?? '';
      _emailController.text = d['email'] ?? '';
      _durationController.text = d['duration'] ?? '';
    }
    if (widget.type == 'student' || widget.type == 'instructor') {
      if (_isEditMode) {
        String s = widget.existingData!['status'] ?? 'active';
        _status = s;
      } else {
        _status = widget.type == 'student' ? 'confirmed' : 'active';
      }
      if (widget.type == 'student') {
        _fetchClasses();
      }
    }
  }

  Future<void> _fetchStudentEnrollment() async {
    try {
      final studentId = widget.existingData!['id'];
      final res = await ApiService.get('/enrollments?student_id=$studentId');
      
      if (res.statusCode == 200) {
        final enrollments = json.decode(res.body);
        if (enrollments.isNotEmpty) {
          setState(() {
            for (var enrollment in enrollments) {
              if (enrollment['class_id'] != null) {
                _tryPreSelect('class_${enrollment['class_id']}');
              } else if (enrollment['course_id'] != null) {
                _tryPreSelect('course_${enrollment['course_id']}');
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  void _tryPreSelect(String uid) {
    if (_classes.isEmpty) return;
    try {
      if (_classes.any((c) => c['unique_id'] == uid)) {
        if (!_selectedIds.contains(uid)) {
          setState(() {
            _selectedIds.add(uid);
            _initialSelectedIds.add(uid);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoadingClasses = true);
    try {
      final classRes = await ApiService.get('/classes');
      final courseRes = await ApiService.get('/courses');
      
      List<dynamic> combined = [];
      if (classRes.statusCode == 200) {
        final data = json.decode(classRes.body);
        if (data is List) {
          combined.addAll(data.map((c) => {
            ...c,
            'unique_id': 'class_${c['id']}',
            'display_name': 'Lớp: ${c['class_name'] ?? c['name'] ?? ''}'
          }));
        }
      }
      if (courseRes.statusCode == 200) {
        final data = json.decode(courseRes.body);
        if (data is List) {
          combined.addAll(data.map((c) => {
            ...c,
            'unique_id': 'course_${c['id']}',
            'display_name': 'Khóa: ${c['name'] ?? ''}',
            'class_name': c['name']
          }));
        }
      }
      
      setState(() {
        _classes = combined;
        _isLoadingClasses = false;
        if (_isEditMode) _fetchStudentEnrollment();
      });
    } catch (e) {
      debugPrint('Error fetching classes: $e');
      setState(() => _isLoadingClasses = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  String get _endpoint {
    switch (widget.type) {
      case 'room': return '/api/rooms';
      case 'course': return '/api/courses';
      case 'student': return '/api/students';
      case 'instructor': return '/api/instructors';
      default: return '/api/rooms';
    }
  }

  String get _title {
    final action = _isEditMode ? 'CHỈNH SỬA' : 'THÊM';
    switch (widget.type) {
      case 'room': return '$action PHÒNG';
      case 'course': return '$action KHÓA HỌC';
      case 'student': return '$action HỌC VIÊN';
      case 'instructor': return '$action GIÁO VIÊN';
      default: return action;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      String url;
      if (_isEditMode) {
        url = '$baseUrl$_endpoint/${widget.existingData!['id']}';
      } else {
        url = '$baseUrl$_endpoint';
      }

      http.Response response;

      final cleanPrice = _priceController.text.replaceAll(RegExp(r'[^\d]'), '');

      // Use multipart only if there's an image (for room/course)
      if (_imageFile != null && widget.type != 'student') {
        final request = http.MultipartRequest(
          _isEditMode ? 'PUT' : 'POST',
          Uri.parse(url),
        );
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        request.fields['name'] = _nameController.text;
        request.fields['description'] = _descriptionController.text;
        if (widget.type == 'room') {
          request.fields['capacity'] = _capacityController.text;
          request.fields['price_per_hour'] = cleanPrice;
          request.fields['facilities'] = _facilitiesController.text;
          request.fields['status'] = 'active';
        } else {
          request.fields['price'] = cleanPrice;
          request.fields['duration'] = _durationController.text;
          request.fields['status'] = 'active';
        }
        request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));
        final streamed = await request.send();
        response = await http.Response.fromStream(streamed);
      } else {
        // JSON request
        Map<String, dynamic> body;
        if (widget.type == 'room') {
          body = {
            'name': _nameController.text,
            'description': _descriptionController.text,
            'capacity': int.tryParse(_capacityController.text) ?? 0,
            'price_per_hour': double.tryParse(cleanPrice) ?? 0,
            'facilities': _facilitiesController.text,
            'status': 'active',
          };
        } else if (widget.type == 'course') {
          body = {
            'name': _nameController.text,
            'description': _descriptionController.text,
            'price': double.tryParse(cleanPrice) ?? 0,
            'duration': _durationController.text,
            'status': 'active',
          };
        } else if (widget.type == 'instructor') {
          body = {
            'name': _nameController.text,
            'phone': _phoneController.text,
            'email': _emailController.text,
            'bio': _descriptionController.text,
            'status': _status,
          };
        } else {
          body = {
            'name': _nameController.text,
            'phone': _phoneController.text,
            'email': _emailController.text,
            'status': _status,
          };
        }

        final headers = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
        if (_isEditMode) {
          response = await http.put(Uri.parse(url), headers: headers, body: json.encode(body));
        } else {
          response = await http.post(Uri.parse(url), headers: headers, body: json.encode(body));
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Handle Enrollment (both Create and Edit mode for student)
        if (widget.type == 'student' && _selectedIds.isNotEmpty) {
          final studentId = _isEditMode ? widget.existingData!['id'] : json.decode(response.body)['id'];
          if (studentId != null) {
            for (String uid in _selectedIds) {
              if (_isEditMode && _initialSelectedIds.contains(uid)) {
                continue; // Skip already enrolled courses to prevent duplicates
              }
              final selected = _classes.firstWhere((c) => c['unique_id'] == uid);
              final isClass = uid.startsWith('class_');
              final id = selected['id'];
              
              await ApiService.post('/enrollments', {
                'student_id': studentId,
                if (isClass) 'class_id': id else 'course_id': id,
              });
            }
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditMode ? 'Cập nhật thành công!' : 'Thêm thành công!'), backgroundColor: RentsColors.accentGreen),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          final data = json.decode(response.body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? data['message'] ?? 'Có lỗi xảy ra'), backgroundColor: RentsColors.accentRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: RentsColors.accentRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgGray,
      appBar: AppBar(
        centerTitle: true,
        title: Text(_title.toUpperCase(), style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: RentsColors.primaryBlue),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image picker (for room and course)
              if (widget.type != 'student') ...[
                _buildImagePicker(),
                const SizedBox(height: 20),
              ],
              // Name
              _buildInput(controller: _nameController, label: 'Tên', icon: Icons.label, validator: (v) => v!.isEmpty ? 'Vui lòng nhập tên' : null),
              const SizedBox(height: 15),
              // Type-specific fields
              if (widget.type == 'room') ...[
                _buildInput(controller: _capacityController, label: 'Sức chứa (người)', icon: Icons.group, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Nhập sức chứa' : null),
                const SizedBox(height: 15),
                _buildInput(controller: _priceController, label: 'Giá thuê (VNĐ/giờ)', icon: Icons.attach_money, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Nhập giá' : null, inputFormatters: [_CurrencyInputFormatter()]),
                const SizedBox(height: 15),
                _buildInput(controller: _facilitiesController, label: 'Trang thiết bị', icon: Icons.devices),
                const SizedBox(height: 15),
                _buildInput(controller: _descriptionController, label: 'Mô tả', icon: Icons.description, maxLines: 3),
              ],
              if (widget.type == 'course') ...[
                _buildInput(controller: _priceController, label: 'Học phí (VNĐ)', icon: Icons.attach_money, keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Nhập học phí' : null, inputFormatters: [_CurrencyInputFormatter()]),
                const SizedBox(height: 15),
                _buildInput(controller: _durationController, label: 'Số buổi học (vd: 12)', icon: Icons.timer, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 15),
                _buildInput(controller: _descriptionController, label: 'Mô tả khóa học', icon: Icons.description, maxLines: 3),
              ],
              if (widget.type == 'student' || widget.type == 'instructor') ...[
                _buildInput(controller: _phoneController, label: 'Số điện thoại', icon: Icons.phone, keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Nhập SĐT' : null),
                const SizedBox(height: 15),
                _buildInput(controller: _emailController, label: 'Email', icon: Icons.email, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 15),
                
                if (widget.type == 'instructor') ...[
                  _buildInput(controller: _descriptionController, label: 'Giới thiệu / Kinh nghiệm', icon: Icons.description, maxLines: 3),
                ],

                if (widget.type == 'student') ...[
                  const Text('GÁN KHÓA HỌC (TÙY CHỌN)', style: TextStyle(fontWeight: FontWeight.bold, color: RentsColors.primaryBlue, fontSize: 13)),
                  const SizedBox(height: 12),
                  _buildClassDropdown(),
                  if (_selectedIds.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildCourseInfoPreview(),
                  ],
                ],
              ],
              const SizedBox(height: 30),
              Container(
                height: 55,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: RentsColors.primaryGradient,
                  boxShadow: [BoxShadow(color: RentsColors.primaryBlue.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                      : Text(_isEditMode ? 'LƯU THAY ĐỔI' : 'THÊM MỚI', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final existingImageUrl = widget.existingData?['image_url'];
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RentsColors.primaryBlue.withValues(alpha: 0.3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: _imageFile != null
              ? Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity)
              : (existingImageUrl != null && existingImageUrl.isNotEmpty
                  ? Image.network('$baseUrl$existingImageUrl', fit: BoxFit.cover, width: double.infinity,
                      errorBuilder: (_, __, ___) => _buildImagePlaceholder())
                  : _buildImagePlaceholder()),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: RentsColors.primaryBlue.withValues(alpha: 0.5)),
        const SizedBox(height: 8),
        Text('Nhấn để chọn ảnh', style: TextStyle(color: RentsColors.grayDark, fontSize: 14)),
      ],
    );
  }

  Widget _buildClassDropdown() {
    if (_isLoadingClasses) {
      return const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đăng ký khóa học/lớp học (có thể chọn nhiều)',
          style: TextStyle(color: RentsColors.grayDark, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _classes.map((c) {
            final String uid = c['unique_id'];
            final bool isSelected = _selectedIds.contains(uid);
            return FilterChip(
              label: Text(c['display_name'] ?? c['class_name'] ?? 'Lớp học'),
              selected: isSelected,
              onSelected: (selected) {
                if (_isEditMode && !selected && _initialSelectedIds.contains(uid)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Không thể hủy lớp/khóa học đã tham gia!'), backgroundColor: RentsColors.accentRed),
                  );
                  return;
                }
                setState(() {
                  if (selected) {
                    _selectedIds.add(uid);
                  } else {
                    _selectedIds.remove(uid);
                  }
                });
              },
              selectedColor: RentsColors.primaryBlue.withValues(alpha: 0.2),
              checkmarkColor: RentsColors.primaryBlue,
              labelStyle: TextStyle(
                color: isSelected ? RentsColors.primaryBlue : RentsColors.grayDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCourseInfoPreview() {
    if (_selectedIds.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RentsColors.primaryBlue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RentsColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: RentsColors.primaryBlue, size: 20),
          const SizedBox(width: 8),
          Text('Đã chọn ${_selectedIds.length} khóa học / lớp học', style: const TextStyle(fontWeight: FontWeight.bold, color: RentsColors.primaryBlue)),
        ],
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
        Text(label, style: const TextStyle(color: RentsColors.grayDark, fontSize: 14, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: RentsColors.black)),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: validator,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontWeight: FontWeight.w600, color: RentsColors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: RentsColors.grayDark),
          prefixIcon: maxLines == 1 ? Icon(icon, color: RentsColors.primaryBlue) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: RentsColors.grayMedium.withValues(alpha: 0.3))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: RentsColors.grayMedium.withValues(alpha: 0.3))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5)),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: RentsColors.grayMedium.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _status,
          items: const [
            DropdownMenuItem(value: 'confirmed', child: Text('Đã xác nhận')),
            DropdownMenuItem(value: 'active', child: Text('Đang học')),
            DropdownMenuItem(value: 'inactive', child: Text('Đã xong')),
            DropdownMenuItem(value: 'suspended', child: Text('Tạm dừng')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _status = val);
          },
        ),
      ),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final cleanString = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanString.isEmpty) return const TextEditingValue(text: '');

    final number = int.parse(cleanString);
    final newText = number.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
