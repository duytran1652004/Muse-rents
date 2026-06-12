import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/globals.dart';
import '../../widgets/notification_button.dart';
import 'package:url_launcher/url_launcher.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  List<dynamic> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _roleFilter = 'all';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _fetchStudents();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _applyFilter();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    try {
      final res = await ApiService.get('/students');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _students = json.decode(res.body);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/users');
      if (res.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _users = data;
          _applyFilter();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    _filteredUsers = _users.where((u) {
      final matchSearch = _searchQuery.isEmpty ||
          (u['full_name'] ?? '').toLowerCase().contains(_searchQuery) ||
          (u['phone_number'] ?? '').contains(_searchQuery);
      final matchRole = _roleFilter == 'all' || u['role'] == _roleFilter;
      return matchSearch && matchRole;
    }).toList();
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['full_name']);
    final phoneController = TextEditingController(text: user['phone_number']);
    final emailController = TextEditingController(text: user['email']);
    String selectedRole = user['role'] ?? 'staff';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Sửa Tài Khoản', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Vai trò',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    if (globalRole.value == 'admin')
                      const DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
                    const DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                    const DropdownMenuItem(value: 'teacher', child: Text('Giáo viên')),
                    const DropdownMenuItem(value: 'student', child: Text('Học viên')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => selectedRole = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: RentsColors.primaryBlue),
              onPressed: () async {
                Navigator.pop(ctx, true);
                try {
                  final res = await ApiService.put('/users/${user['id']}', {
                    'full_name': nameController.text,
                    'phone_number': phoneController.text,
                    'email': emailController.text,
                    'role': selectedRole,
                  });
                  if (res.statusCode == 200) {
                    _fetchUsers();
                  } else {
                    final data = json.decode(res.body);
                    ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Lỗi')));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối')));
                }
              },
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPendingAccountDetail(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['full_name']);
    final phoneController = TextEditingController(text: user['phone_number']);
    String selectedRole = user['role'] ?? 'student';
    int? selectedStudentId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 4),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.person_outline, size: 28, color: Color(0xFFE6A817)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chi tiết tài khoản chờ xác nhận',
                                  style: TextStyle(fontSize: 13, color: RentsColors.grayDark)),
                              Text(user['full_name'] ?? 'Chưa cập nhật',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: RentsColors.black)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3CD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Chờ duyệt',
                              style: TextStyle(color: Color(0xFFE6A817), fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 28, indent: 20, endIndent: 20),
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Read-only info section
                          _sectionTitle('Thông tin đăng ký'),
                          const SizedBox(height: 12),
                          _infoRow(Icons.person, 'Họ và tên', user['full_name'] ?? 'Chưa cập nhật'),
                          _infoRow(Icons.phone_outlined, 'Số điện thoại', user['phone_number'] ?? 'Chưa cập nhật'),
                          _infoRow(Icons.account_circle_outlined, 'Tên tài khoản', user['email'] ?? 'Chưa cập nhật'),
                          if (user['created_at'] != null)
                            _infoRow(Icons.calendar_today_outlined, 'Ngày đăng ký',
                                _formatDate(user['created_at'].toString())),
                          const SizedBox(height: 20),
                          // Editable section
                          _sectionTitle('Xác nhận & Phân quyền'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: 'Họ và tên (có thể sửa)',
                              prefixIcon: const Icon(Icons.edit_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Số điện thoại (có thể sửa)',
                              prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedRole,
                            decoration: InputDecoration(
                              labelText: 'Vai trò',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
                              ),
                            ),
                            items: [
                              if (globalRole.value == 'admin')
                                const DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
                              const DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                              const DropdownMenuItem(value: 'teacher', child: Text('Giáo viên')),
                              const DropdownMenuItem(value: 'student', child: Text('Học viên')),
                            ],
                            onChanged: (v) {
                              if (v != null) setSheetState(() => selectedRole = v);
                            },
                          ),
                          // Student linking section
                          if (selectedRole == 'student') ...[
                            const SizedBox(height: 20),
                            _sectionTitle('Gán vào học viên đã có'),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F7FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBFD9F5)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, size: 16, color: RentsColors.primaryBlue),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Nếu học viên đã được thêm thủ công trước đó, hãy chọn để liên kết tài khoản này.',
                                      style: TextStyle(fontSize: 12, color: RentsColors.primaryBlue),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              value: selectedStudentId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Chọn học viên để gán',
                                prefixIcon: const Icon(Icons.link, size: 18),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('— Tạo học viên mới —', style: TextStyle(color: RentsColors.grayDark)),
                                ),
                                ..._students.map((s) => DropdownMenuItem<int>(
                                  value: s['id'] as int,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(s['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      if (s['phone'] != null && s['phone'].toString().isNotEmpty)
                                        Text(s['phone'], style: const TextStyle(fontSize: 12, color: RentsColors.grayDark)),
                                    ],
                                  ),
                                )),
                              ],
                              onChanged: (v) => setSheetState(() => selectedStudentId = v),
                              selectedItemBuilder: (ctx) => [
                                const Text('— Tạo học viên mới —'),
                                ..._students.map((s) => Text(
                                  '${s['name']} ${s['phone'] != null && s['phone'].toString().isNotEmpty ? "· ${s['phone']}" : ""}',
                                  overflow: TextOverflow.ellipsis,
                                )),
                              ],
                            ),
                            if (selectedStudentId != null) ...[
                              const SizedBox(height: 10),
                              Builder(builder: (_) {
                                final linked = _students.firstWhere(
                                  (s) => s['id'] == selectedStudentId,
                                  orElse: () => {},
                                );
                                if (linked.isEmpty) return const SizedBox();
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FFF4),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA3D9B1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.check_circle_outline, size: 16, color: RentsColors.accentGreen),
                                          const SizedBox(width: 6),
                                          Text('Sẽ gán vào: ${linked['name']}',
                                              style: const TextStyle(fontWeight: FontWeight.w700, color: RentsColors.accentGreen, fontSize: 13)),
                                        ],
                                      ),
                                      if (linked['phone'] != null && linked['phone'].toString().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4, left: 22),
                                          child: Text('SĐT: ${linked['phone']}',
                                              style: const TextStyle(fontSize: 12, color: RentsColors.grayDark)),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                  // Action buttons
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Reject button
                        OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _deleteUser(user['id']);
                          },
                          icon: const Icon(Icons.close, size: 18, color: RentsColors.accentRed),
                          label: const Text('Từ chối', style: TextStyle(color: RentsColors.accentRed, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: RentsColors.accentRed),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Approve button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              try {
                                final res = await ApiService.put('/users/${user['id']}', {
                                  'full_name': nameController.text,
                                  'phone_number': phoneController.text,
                                  'email': user['email'],
                                  'role': selectedRole,
                                  'status': 'active',
                                  if (selectedRole == 'student' && selectedStudentId != null)
                                    'linked_student_id': selectedStudentId,
                                });
                                if (res.statusCode == 200) {
                                  _fetchUsers();
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text(selectedStudentId != null
                                            ? 'Đã duyệt và gán vào học viên thành công'
                                            : 'Đã duyệt tài khoản thành công'),
                                        backgroundColor: RentsColors.accentGreen,
                                      ),
                                    );
                                  }
                                } else {
                                  final data = json.decode(res.body);
                                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(
                                    SnackBar(content: Text(data['message'] ?? 'Lỗi')));
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(content: Text('Lỗi kết nối')));
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                            label: const Text('Xác nhận duyệt',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: RentsColors.accentGreen,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
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

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: RentsColors.primaryBlue, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: RentsColors.black)),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: RentsColors.primaryBlue),
          const SizedBox(width: 10),
          SizedBox(width: 110, child: Text(label, style: const TextStyle(fontSize: 13, color: RentsColors.grayDark))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: RentsColors.black))),
        ],
      ),
    );
  }

  Future<void> _deleteUser(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.w800, color: RentsColors.accentRed)),
        content: const Text('Bạn có chắc chắn muốn xóa tài khoản này? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: RentsColors.accentRed),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ApiService.delete('/users/$id');
        if (res.statusCode == 200) {
          _fetchUsers();
        } else {
          final data = json.decode(res.body);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Lỗi')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: RentsColors.bgLightBlue,
        appBar: AppBar(
          centerTitle: true,
          backgroundColor: RentsColors.bgLightBlue,
          elevation: 0,
          leading: const NotificationButton(),
          title: const Text('QUẢN LÝ TÀI KHOẢN', style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w800, fontSize: 20)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue), onPressed: () { _fetchUsers(); _fetchStudents(); }),
          ],
          bottom: const TabBar(
            labelColor: RentsColors.primaryBlue,
            unselectedLabelColor: RentsColors.grayDark,
            indicatorColor: RentsColors.primaryBlue,
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(text: 'Tài khoản'),
              Tab(text: 'Xác nhận'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildSearchAndFilter(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildUserList('active'),
                  _buildUserList('pending'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(String status) {
    final list = _filteredUsers.where((u) => (u['status'] ?? 'active') == status).toList();
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue));
    }
    if (list.isEmpty) {
      return Center(child: Text(status == 'active' ? 'Không tìm thấy tài khoản nào' : 'Không có yêu cầu xác nhận nào'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, index) => _buildUserCard(list[index]),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: RentsColors.bgLightBlue,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, SĐT...',
              hintStyle: const TextStyle(color: RentsColors.grayMedium, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: RentsColors.grayDark, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); })
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tất cả'),
                const SizedBox(width: 8),
                _buildFilterChip('admin', 'Admin'),
                const SizedBox(width: 8),
                _buildFilterChip('staff', 'Staff'),
                const SizedBox(width: 8),
                _buildFilterChip('teacher', 'Teacher'),
                const SizedBox(width: 8),
                _buildFilterChip('student', 'Student'),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isActive = _roleFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _roleFilter = value;
          _applyFilter();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? RentsColors.primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? RentsColors.primaryBlue : RentsColors.grayLight),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : RentsColors.grayDark,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = user['full_name'] ?? 'Không tên';
    final role = user['role'] ?? 'staff';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Color roleColor;
    String roleName;
    switch (role) {
      case 'admin':
        roleColor = const Color(0xFFFF6B35);
        roleName = 'Admin';
        break;
      case 'teacher':
        roleColor = const Color(0xFF2ECC71);
        roleName = 'Teacher';
        break;
      case 'student':
        roleColor = const Color(0xFF9B59B6);
        roleName = 'Student';
        break;
      default:
        roleColor = const Color(0xFF3498DB);
        roleName = 'Staff';
    }

    final isPending = user['status'] == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: RentsColors.softCardShadow,
        border: isPending ? Border.all(color: const Color(0xFFFFD27F), width: 1.5) : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: isPending ? () => _showPendingAccountDetail(user) : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(
                child: Text(initials, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: roleColor)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(roleName, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (user['phone_number'] != null && user['phone_number'].toString().isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        final phone = user['phone_number'].toString();
                        final Uri url = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 15, color: RentsColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(user['phone_number'], style: const TextStyle(color: RentsColors.primaryBlue, fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (user['status'] == 'pending')
              const Icon(Icons.chevron_right, color: RentsColors.grayMedium)
            else if (globalRole.value == 'admin' || user['role'] != 'admin') ...[
              IconButton(icon: const Icon(Icons.edit, color: RentsColors.primaryBlue), onPressed: () => _editUser(user)),
              IconButton(icon: const Icon(Icons.delete, color: RentsColors.accentRed), onPressed: () => _deleteUser(user['id'])),
            ]
          ],
          ),
        ),
      ),
    );
  }
}
