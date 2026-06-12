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
