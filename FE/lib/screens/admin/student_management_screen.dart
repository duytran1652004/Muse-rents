import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import 'edit_item_screen.dart';
import 'student_detail_screen.dart';
import 'instructor_detail_screen.dart'; // We will create this
import '../../widgets/notification_button.dart';
import '../../utils/globals.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Student state
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoadingStudents = true;
  String _studentFilter = 'all';

  // Instructor state
  List<dynamic> _instructors = [];
  List<dynamic> _filteredInstructors = [];
  bool _isLoadingInstructors = true;
  String _instructorFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to update FAB and search hints
        _applyFilter();
      }
    });
    _fetchStudents();
    _fetchInstructors();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final response = await ApiService.get('/students');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _students = json.decode(response.body);
            _applyFilter();
            _isLoadingStudents = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingStudents = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _fetchInstructors() async {
    setState(() => _isLoadingInstructors = true);
    try {
      final response = await ApiService.get('/instructors');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _instructors = json.decode(response.body);
            _applyFilter();
            _isLoadingInstructors = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingInstructors = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingInstructors = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      // Filter Students
      _filteredStudents = _students.where((s) {
        final matchSearch = query.isEmpty ||
            (s['name'] ?? '').toLowerCase().contains(query) ||
            (s['phone'] ?? '').contains(query);
        final matchStatus = _studentFilter == 'all' || s['status'] == _studentFilter;
        return matchSearch && matchStatus;
      }).toList();

      // Filter Instructors
      _filteredInstructors = _instructors.where((i) {
        final matchSearch = query.isEmpty ||
            (i['name'] ?? '').toLowerCase().contains(query) ||
            (i['phone'] ?? '').contains(query);
        final matchStatus = _instructorFilter == 'all' || i['status'] == _instructorFilter;
        return matchSearch && matchStatus;
      }).toList();
    });
  }

  Future<void> _openEditStudent(Map<String, dynamic>? student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditItemScreen(type: 'student', existingData: student)),
    );
    if (result == true) _fetchStudents();
  }

  Future<void> _openEditInstructor(Map<String, dynamic>? instructor) async {
    // Reusing EditItemScreen for instructor
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditItemScreen(type: 'instructor', existingData: instructor)),
    );
    if (result == true) _fetchInstructors();
  }

  void _openStudentDetail(Map<String, dynamic> student) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
    ).then((_) => _fetchStudents());
  }

  void _openInstructorDetail(Map<String, dynamic> instructor) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InstructorDetailScreen(instructor: instructor)),
    ).then((_) => _fetchInstructors());
  }

  @override
  Widget build(BuildContext context) {
    final isStudentTab = _tabController.index == 0;
    
    return ValueListenableBuilder<String>(
      valueListenable: globalRole,
      builder: (context, role, child) {
        final isAdmin = role == 'admin';
        return Scaffold(
          backgroundColor: RentsColors.bgLightBlue,
          appBar: _buildAppBar(),
          body: Column(
        children: [
          _buildSearchAndFilter(isStudentTab),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStudentList(),
                _buildInstructorList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: (isAdmin && isStudentTab) ? FloatingActionButton(
        onPressed: () => _openEditStudent(null),
        backgroundColor: RentsColors.primaryBlue,
        child: const Icon(Icons.person_add, color: Colors.white),
      ) : null,
    );
  },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: true,
      backgroundColor: RentsColors.bgLightBlue,
      elevation: 0,
      leading: const NotificationButton(),
      title: const Text(
        'NHÂN SỰ & HỌC VIÊN',
        style: TextStyle(color: RentsColors.black, fontWeight: FontWeight.w800, fontSize: 20),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
          onPressed: () {
            if (_tabController.index == 0) _fetchStudents();
            else _fetchInstructors();
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: RentsColors.primaryBlue,
        unselectedLabelColor: RentsColors.grayDark,
        indicatorColor: RentsColors.primaryBlue,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        tabs: const [
          Tab(text: 'Học viên'),
          Tab(text: 'Giáo viên'),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isStudentTab) {
    return Container(
      color: RentsColors.bgLightBlue,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          // Search
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
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); _applyFilter(); })
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          // Filter tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: isStudentTab ? _buildStudentFilters() : _buildInstructorFilters(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentFilters() {
    return Row(
      children: [
        {'key': 'all', 'label': 'Tất cả'},
        {'key': 'confirmed', 'label': 'Đã xác nhận'},
        {'key': 'active', 'label': 'Đang học'},
        {'key': 'inactive', 'label': 'Đã xong'},
        {'key': 'suspended', 'label': 'Tạm dừng'},
      ].map((f) {
        final isActive = _studentFilter == f['key'];
        final color = f['key'] == 'confirmed' ? RentsColors.accentOrange : f['key'] == 'active' ? RentsColors.accentGreen : (f['key'] == 'suspended' ? RentsColors.accentRed : RentsColors.primaryBlue);
        return GestureDetector(
          onTap: () { setState(() => _studentFilter = f['key'] as String); _applyFilter(); },
          child: _buildFilterChip(f['label'] as String, isActive, color),
        );
      }).toList(),
    );
  }

  Widget _buildInstructorFilters() {
    return Row(
      children: [
        {'key': 'all', 'label': 'Tất cả'},
        {'key': 'active', 'label': 'Đang dạy'},
        {'key': 'inactive', 'label': 'Nghỉ việc'},
      ].map((f) {
        final isActive = _instructorFilter == f['key'];
        final color = f['key'] == 'inactive' ? RentsColors.accentRed : RentsColors.accentGreen;
        return GestureDetector(
          onTap: () { setState(() => _instructorFilter = f['key'] as String); _applyFilter(); },
          child: _buildFilterChip(f['label'] as String, isActive, color),
        );
      }).toList(),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, Color color) {
    if (label == 'Tất cả') color = RentsColors.primaryBlue;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : RentsColors.grayLight),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : RentsColors.grayDark,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    return CustomScrollView(
      slivers: [
        if (_isLoadingStudents)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue)))
        else if (_filteredStudents.isEmpty)
          SliverFillRemaining(child: _buildEmptyState('Không tìm thấy học viên nào', Icons.people_outline))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildUserCard(_filteredStudents[i], true),
                childCount: _filteredStudents.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildInstructorList() {
    return CustomScrollView(
      slivers: [
        if (_isLoadingInstructors)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue)))
        else if (_filteredInstructors.isEmpty)
          SliverFillRemaining(child: _buildEmptyState('Không tìm thấy giáo viên nào', Icons.school_outlined))
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildUserCard(_filteredInstructors[i], false),
                childCount: _filteredInstructors.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, bool isStudent) {
    final statusColor = isStudent ? _studentStatusColor(user['status']) : _instructorStatusColor(user['status']);
    final statusLabel = isStudent ? _studentStatusLabel(user['status']) : _instructorStatusLabel(user['status']);
    final name = user['name'] ?? 'Không tên';
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
        onTap: () => isStudent ? _openStudentDetail(user) : _openInstructorDetail(user),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: isStudent ? RentsColors.primaryGradient : const LinearGradient(colors: [RentsColors.accentGreen, Color(0xFF1AA95B)]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
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
                          child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: RentsColors.black)),
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
                    const SizedBox(height: 10),
                    if (user['phone'] != null && user['phone'].toString().isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final phone = user['phone'].toString();
                          final Uri url = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          }
                        },
                        child: Row(children: [
                          const Icon(Icons.phone_outlined, size: 15, color: RentsColors.primaryBlue),
                          const SizedBox(width: 6),
                          Text(user['phone'], style: const TextStyle(color: RentsColors.primaryBlue, fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    if (user['email'] != null && user['email'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: [
                          const Icon(Icons.email_outlined, size: 15, color: RentsColors.grayDark),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(user['email'], style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
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

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: RentsColors.grayMedium),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(color: RentsColors.grayDark, fontSize: 15)),
        ],
      ),
    );
  }

  Color _studentStatusColor(String? s) {
    switch (s) {
      case 'confirmed': return RentsColors.accentOrange;
      case 'active': return RentsColors.accentGreen;
      case 'inactive': return RentsColors.primaryBlue;
      case 'suspended': return RentsColors.accentRed;
      default: return RentsColors.grayDark;
    }
  }

  String _studentStatusLabel(String? s) {
    switch (s) {
      case 'confirmed': return 'Đã xác nhận';
      case 'active': return 'Đang học';
      case 'inactive': return 'Đã xong';
      case 'suspended': return 'Tạm dừng';
      default: return s ?? '';
    }
  }

  Color _instructorStatusColor(String? s) {
    switch (s) {
      case 'active': return RentsColors.accentGreen;
      case 'inactive': return RentsColors.accentRed;
      default: return RentsColors.grayDark;
    }
  }

  String _instructorStatusLabel(String? s) {
    switch (s) {
      case 'active': return 'Đang dạy';
      case 'inactive': return 'Nghỉ việc';
      default: return s ?? '';
    }
  }
}
