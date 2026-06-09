import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_screen.dart';
import 'course_management_screen.dart';
import 'room_management_screen.dart';
import 'student_management_screen.dart';
import 'user_management_screen.dart';
import 'revenue_report_screen.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const SettingsScreen({super.key, this.onNavigate});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic> _profile = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditMode = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _changePassword = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _fetchProfile();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await ApiService.get('/auth/me');
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        setState(() {
          _profile = data;
          _nameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone_number'] ?? '';
          _emailController.text = data['email'] ?? '';
          _isLoading = false;
        });
        _animController.forward();
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Tên nhân viên không được để trống', isError: true);
      return;
    }
    if (_changePassword) {
      if (_newPassController.text.isEmpty || _currentPassController.text.isEmpty) {
        _showSnack('Vui lòng điền đầy đủ thông tin mật khẩu', isError: true);
        return;
      }
      if (_newPassController.text != _confirmPassController.text) {
        _showSnack('Mật khẩu mới không khớp', isError: true);
        return;
      }
      if (_newPassController.text.length < 6) {
        _showSnack('Mật khẩu mới tối thiểu 6 ký tự', isError: true);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final body = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
      };
      if (_changePassword) {
        body['current_password'] = _currentPassController.text;
        body['new_password'] = _newPassController.text;
      }

      final res = await ApiService.put('/auth/profile', body);
      final data = json.decode(res.body);

      if (res.statusCode == 200 && mounted) {
        setState(() {
          _profile = {..._profile, ...data['user'] ?? {}};
          _isEditMode = false;
          _changePassword = false;
          _currentPassController.clear();
          _newPassController.clear();
          _confirmPassController.clear();
          _isSaving = false;
        });
        _showSnack('Cập nhật thông tin thành công!');
      } else {
        if (mounted) {
          setState(() => _isSaving = false);
          _showSnack(data['error'] ?? 'Cập nhật thất bại', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Lỗi kết nối máy chủ', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? RentsColors.accentRed : const Color(0xFF2ECC71),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('ĐĂNG XUẤT', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: RentsColors.accentRed),
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'admin':
        return '👑 Quản trị viên';
      case 'staff':
        return '💼 Nhân viên';
      case 'teacher':
        return '👨‍🏫 Giáo viên';
      default:
        return '💼 Nhân viên';
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFF6B35);
      case 'teacher':
        return const Color(0xFF2ECC71);
      default:
        return const Color(0xFF3498DB);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _profile['full_name'] ?? '';
    final email = _profile['email'] ?? '';
    final phone = _profile['phone_number'] ?? '';
    final role = _profile['role'] ?? 'staff';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'N';

    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
        centerTitle: true,
            pinned: true,
            expandedHeight: 200,
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (!_isLoading && !_isEditMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: () => setState(() => _isEditMode = true),
                    icon: const Icon(Icons.edit_rounded, size: 18, color: Colors.white),
                    label: const Text('Sửa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              if (_isEditMode)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditMode = false;
                        _changePassword = false;
                        _nameController.text = _profile['full_name'] ?? '';
                        _phoneController.text = _profile['phone_number'] ?? '';
                        _emailController.text = _profile['email'] ?? '';
                        _currentPassController.clear();
                        _newPassController.clear();
                        _confirmPassController.clear();
                      });
                    },
                    child: const Text('Hủy', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: const BoxDecoration(gradient: RentsColors.primaryGradient),
                child: SafeArea(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Center(
                            child: Text(initial, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getRoleLabel(role),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(padding: EdgeInsets.all(80), child: Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue)))
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Profile Info Card
                          _buildSectionCard(
                            title: 'THÔNG TIN CÁ NHÂN',
                            icon: Icons.person_outline_rounded,
                            color: RentsColors.primaryBlue,
                            children: _isEditMode
                                ? [
                                    _buildEditField(
                                      controller: _nameController,
                                      label: 'Họ và tên',
                                      icon: Icons.badge_outlined,
                                      hint: 'Nhập họ và tên',
                                    ),
                                    const SizedBox(height: 14),
                                    _buildEditField(
                                      controller: _phoneController,
                                      label: 'Số điện thoại',
                                      icon: Icons.phone_outlined,
                                      hint: 'Nhập số điện thoại',
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ]
                                : [
                                    _buildInfoRow(Icons.badge_outlined, 'Họ và tên', name.isNotEmpty ? name : '—'),
                                    _buildDivider(),
                                    _buildInfoRow(
                                      Icons.phone_outlined, 
                                      'Số điện thoại', 
                                      phone.isNotEmpty ? phone : '—',
                                      onTap: () async {
                                        if (phone.isNotEmpty && phone != '—') {
                                          final Uri url = Uri.parse('tel:$phone');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url);
                                          }
                                        }
                                      },
                                    ),
                                    _buildDivider(),
                                    _buildInfoRow(Icons.shield_outlined, 'Vai trò', _getRoleLabel(role), color: _getRoleColor(role)),
                                  ],
                          ),
                          const SizedBox(height: 16),

                          // Password section (only in edit mode)
                          if (_isEditMode) ...[
                            _buildSectionCard(
                              title: 'ĐỔI MẬT KHẨU',
                              icon: Icons.lock_outline_rounded,
                              color: const Color(0xFF6C63FF),
                              children: [
                                Row(
                                  children: [
                                    Switch(
                                      value: _changePassword,
                                      onChanged: (v) => setState(() => _changePassword = v),
                                      activeColor: const Color(0xFF6C63FF),
                                    ),
                                    const Text('Thay đổi mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                if (_changePassword) ...[
                                  const SizedBox(height: 12),
                                  _buildEditField(
                                    controller: _currentPassController,
                                    label: 'Mật khẩu hiện tại',
                                    icon: Icons.lock_outlined,
                                    hint: 'Nhập mật khẩu hiện tại',
                                    isPassword: true,
                                    obscure: _obscureCurrent,
                                    onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEditField(
                                    controller: _newPassController,
                                    label: 'Mật khẩu mới',
                                    icon: Icons.lock_open_outlined,
                                    hint: 'Tối thiểu 6 ký tự',
                                    isPassword: true,
                                    obscure: _obscureNew,
                                    onToggle: () => setState(() => _obscureNew = !_obscureNew),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildEditField(
                                    controller: _confirmPassController,
                                    label: 'Xác nhận mật khẩu mới',
                                    icon: Icons.check_circle_outline,
                                    hint: 'Nhập lại mật khẩu mới',
                                    isPassword: true,
                                    obscure: _obscureConfirm,
                                    onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: RentsColors.primaryBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 4,
                                  shadowColor: RentsColors.primaryBlue.withValues(alpha: 0.4),
                                ),
                                child: _isSaving
                                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.save_rounded, size: 20),
                                          SizedBox(width: 8),
                                          Text('LƯU THÔNG TIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                                        ],
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Management options (always visible)
                          if (!_isEditMode) ...[
                            if (role != 'teacher') ...[
                              _buildSectionCard(
                                title: 'QUẢN LÝ NỘI DUNG',
                                icon: Icons.dashboard_rounded,
                                color: const Color(0xFF2ECC71),
                                children: [
                                  if (role == 'admin') ...[
                                    _buildMenuItem(
                                      Icons.manage_accounts_outlined,
                                      'QUẢN LÝ TÀI KHOẢN',
                                      'Phân quyền, sửa đổi chức vụ',
                                      RentsColors.primaryBlue,
                                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                                    ),
                                    _buildDivider(),
                                  ],
                                  _buildMenuItem(
                                    Icons.door_front_door_outlined,
                                    'QUẢN LÝ PHÒNG',
                                    'Thêm, sửa, xóa phòng',
                                    RentsColors.primaryBlue,
                                    () => widget.onNavigate != null ? widget.onNavigate!(1) : Navigator.push(context, MaterialPageRoute(builder: (_) => const RoomManagementScreen())),
                                  ),
                                  _buildDivider(),
                                  _buildMenuItem(
                                    Icons.people_alt_outlined,
                                    'QUẢN LÝ HỌC VIÊN',
                                    'Thêm, sửa, xóa học viên',
                                    RentsColors.primaryBlue,
                                    () => widget.onNavigate != null ? widget.onNavigate!(2) : Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentManagementScreen())),
                                  ),
                                  _buildDivider(),
                                  _buildMenuItem(
                                    Icons.library_books_rounded,
                                    'QUẢN LÝ KHÓA HỌC',
                                    'Thêm, sửa, xóa khóa học',
                                    RentsColors.primaryBlue,
                                    () => widget.onNavigate != null ? widget.onNavigate!(3) : Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseManagementScreen())),
                                  ),
                                  _buildDivider(),
                                  _buildMenuItem(
                                    Icons.analytics_outlined,
                                    'BÁO CÁO DOANH THU',
                                    'Theo dõi doanh thu phòng và khóa học',
                                    RentsColors.primaryBlue,
                                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RevenueReportScreen())),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            _buildSectionCard(
                              title: 'HỆ THỐNG',
                              icon: Icons.settings_rounded,
                              color: RentsColors.grayDark,
                              children: [
                                _buildMenuItem(
                                  Icons.logout_rounded,
                                  'Đăng xuất',
                                  'Thoát khỏi tài khoản hiện tại',
                                  RentsColors.accentRed,
                                  _logout,
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.8)),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: RentsColors.softCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: RentsColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: RentsColors.primaryBlue, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: RentsColors.grayDark, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color ?? RentsColors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: RentsColors.grayDark)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: RentsColors.grayDark.withValues(alpha: 0.5), fontWeight: FontWeight.w400),
            prefixIcon: Icon(icon, color: RentsColors.primaryBlue, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: RentsColors.grayDark, size: 20),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: RentsColors.bgLightBlue,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Divider(height: 1, color: Color(0xFFEEEEEE)),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, color: RentsColors.black, fontSize: 15)),
      subtitle: Text(subtitle, style: const TextStyle(color: RentsColors.grayDark, fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, color: RentsColors.grayMedium),
      onTap: onTap,
      ),
    );
  }
}
