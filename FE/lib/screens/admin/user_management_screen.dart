import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/globals.dart';
import '../../widgets/notification_button.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _roleFilter = 'all';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
                    DropdownMenuItem(value: 'staff', child: Text('Nhân viên')),
                    DropdownMenuItem(value: 'teacher', child: Text('Giáo viên')),
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
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: RentsColors.bgLightBlue,
        elevation: 0,
        title: const Text('QUẢN LÝ TÀI KHOẢN', style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue), onPressed: _fetchUsers),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
                : _filteredUsers.isEmpty
                    ? const Center(child: Text('Không tìm thấy tài khoản nào'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                      ),
          ),
        ],
      ),
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
      default:
        roleColor = const Color(0xFF3498DB);
        roleName = 'Staff';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Center(
                child: Text(initials, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: roleColor)),
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
                        child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                        child: Text(roleName, style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (user['phone_number'] != null && user['phone_number'].toString().isNotEmpty)
                    Text(user['phone_number'], style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.edit, color: RentsColors.primaryBlue), onPressed: () => _editUser(user)),
                IconButton(icon: const Icon(Icons.delete, color: RentsColors.accentRed), onPressed: () => _deleteUser(user['id'])),
              ],
            )
          ],
        ),
      ),
    );
  }
}
