import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import 'edit_item_screen.dart';
import 'student_detail_screen.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  List<dynamic> _students = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/students');
      if (response.statusCode == 200) {
        setState(() {
          _students = json.decode(response.body);
          _applyFilter();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _students.where((s) {
        final matchSearch = query.isEmpty ||
            (s['name'] ?? '').toLowerCase().contains(query) ||
            (s['phone'] ?? '').contains(query) ||
            (s['email'] ?? '').toLowerCase().contains(query);
        final matchStatus = _filterStatus == 'all' || s['status'] == _filterStatus;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  Future<void> _openEdit(Map<String, dynamic>? student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditItemScreen(type: 'student', existingData: student)),
    );
    if (result == true) _fetchStudents();
  }

  void _openDetail(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
    ).then((_) => _fetchStudents());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildSearchAndFilter()),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue)))
          else if (_filtered.isEmpty)
            SliverFillRemaining(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildStudentCard(_filtered[i]),
                  childCount: _filtered.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(null),
        backgroundColor: RentsColors.primaryBlue,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
        centerTitle: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'QUẢN LÝ HỌC VIÊN',
        style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w800, fontSize: 20),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: RentsColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_filtered.length} học viên',
                style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: RentsColors.grayLight),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Search
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, SĐT, email...',
              hintStyle: const TextStyle(color: RentsColors.grayMedium, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: RentsColors.grayDark, size: 20),
              filled: true,
              fillColor: RentsColors.bgLightBlue,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: RentsColors.primaryBlue, width: 1.5),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _applyFilter(); })
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                {'key': 'all', 'label': 'Tất cả'},
                {'key': 'confirmed', 'label': 'Đã xác nhận'},
                {'key': 'active', 'label': 'Đang học'},
                {'key': 'inactive', 'label': 'Đã xong'},
                {'key': 'suspended', 'label': 'Tạm dừng'},
              ].map((f) {
                final isActive = _filterStatus == f['key'];
                final color = f['key'] == 'confirmed' ? RentsColors.accentOrange : f['key'] == 'active' ? RentsColors.accentGreen : (f['key'] == 'suspended' ? RentsColors.accentRed : RentsColors.primaryBlue);
                return GestureDetector(
                  onTap: () { setState(() => _filterStatus = f['key'] as String); _applyFilter(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? color : RentsColors.bgLightBlue,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isActive ? color : RentsColors.grayLight),
                    ),
                    child: Text(
                      f['label'] as String,
                      style: TextStyle(
                        color: isActive ? Colors.white : RentsColors.grayDark,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final statusColor = _statusColor(student['status']);
    final statusLabel = _statusLabel(student['status']);
    final name = student['name'] ?? 'Không tên';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openDetail(student),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: RentsColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: RentsColors.black)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (student['phone'] != null)
                      Row(children: [
                        const Icon(Icons.phone_outlined, size: 13, color: RentsColors.grayDark),
                        const SizedBox(width: 4),
                        Text(student['phone'], style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                      ]),
                    if (student['email'] != null) ...[
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.email_outlined, size: 13, color: RentsColors.grayDark),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(student['email'], style: const TextStyle(color: RentsColors.grayDark, fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
              // Arrow
              const Icon(Icons.chevron_right, color: RentsColors.grayMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, size: 64, color: RentsColors.grayMedium),
          const SizedBox(height: 12),
          Text(
            _searchController.text.isNotEmpty ? 'Không tìm thấy học viên nào' : 'Chưa có học viên nào',
            style: const TextStyle(color: RentsColors.grayDark, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'confirmed': return RentsColors.accentOrange;
      case 'active': return RentsColors.accentGreen;
      case 'inactive': return RentsColors.primaryBlue;
      case 'suspended': return RentsColors.accentRed;
      default: return RentsColors.grayDark;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'confirmed': return 'Đã xác nhận';
      case 'active': return 'Đang học';
      case 'inactive': return 'Đã xong';
      case 'suspended': return 'Tạm dừng / Đã hủy';
      default: return s ?? '';
    }
  }
}
