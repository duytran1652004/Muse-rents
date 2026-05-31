import 'dart:convert';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/rents_colors.dart';
import 'edit_item_screen.dart';
import 'course_detail_sheet.dart';
import '../../widgets/notification_button.dart';

class CourseManagementScreen extends StatefulWidget {
  const CourseManagementScreen({super.key});

  @override
  State<CourseManagementScreen> createState() => _CourseManagementScreenState();
}

class _CourseManagementScreenState extends State<CourseManagementScreen> {
  static const String baseUrl = ApiService.serverUrl;

  final List<Map<String, String>> _filters = const [
    {'key': 'all', 'label': 'Tất cả'},
    {'key': 'active', 'label': 'Đang mở'},
    {'key': 'inactive', 'label': 'Tạm dừng'},
  ];

  List<dynamic> _courses = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCourses() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/courses');
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _courses = json.decode(response.body) as List<dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<dynamic> get _filteredCourses {
    final query = _searchController.text.toLowerCase();
    return _courses.where((course) {
      final status = (course['status'] ?? 'inactive').toString();
      final matchStatus = _filterStatus == 'all' || status == _filterStatus;
      final name = (course['name'] ?? '').toString().toLowerCase();
      final matchSearch = name.contains(query);
      return matchStatus && matchSearch;
    }).toList();
  }

  Future<void> _openEdit(Map<String, dynamic>? course) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditItemScreen(type: 'course', existingData: course),
      ),
    );

    if (result == true) {
      _fetchCourses();
    }
  }

  void _showCourseDetail(Map<String, dynamic> course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CourseDetailSheet(
        course: course,
        baseUrl: baseUrl,
        onEdit: () {
          Navigator.pop(context);
          _openEdit(course);
        },
        onStatusChange: (id, status) async {
          await ApiService.put('/courses/$id', {
            'name': course['name'],
            'description': course['description'],
            'price': course['price'],
            'duration': course['duration'],
            'status': status,
          });
          _fetchCourses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (_isLoading)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: RentsColors.primaryBlue,
                      ),
                    ),
                  )
                else if (_filteredCourses.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  _buildCourseGrid(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEdit(null),
        backgroundColor: RentsColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      centerTitle: true,
      backgroundColor: RentsColors.bgLightBlue,
      elevation: 0,
      leading: const NotificationButton(),
      title: const Text(
        'QUẢN LÝ KHÓA HỌC',
        style: TextStyle(
          color: RentsColors.black,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
          onPressed: _fetchCourses,
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
      color: RentsColors.bgLightBlue,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm khóa học...',
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
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchController.clear())
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters.map((filter) {
                final isActive = _filterStatus == filter['key'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _filterStatus = filter['key'] ?? 'all'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? RentsColors.primaryBlue
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isActive
                            ? RentsColors.primaryBlue
                            : RentsColors.grayLight,
                      ),
                    ),
                    child: Text(
                      filter['label'] ?? '',
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

  Widget _buildCourseGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, index) =>
              _buildCourseCard(_filteredCourses[index] as Map<String, dynamic>),
          childCount: _filteredCourses.length,
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final imageUrl = (course['image_url'] ?? '').toString();
    final status = (course['status'] ?? 'inactive').toString();
    final isActive = status == 'active';
    final statusColor = isActive
        ? RentsColors.accentGreen
        : RentsColors.accentOrange;
    final statusLabel = isActive ? 'Đang mở' : 'Tạm dừng';
    final duration = _courseDuration(course);
    final description = (course['description'] ?? '').toString().trim();

    return GestureDetector(
      onTap: () => _showCourseDetail(course),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              '$baseUrl$imageUrl',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        statusLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (description.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.6),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (course['name'] ?? '').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: RentsColors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: RentsColors.grayDark,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            duration,
                            style: const TextStyle(
                              color: RentsColors.grayDark,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatPrice(course['price']),
                          style: const TextStyle(
                            color: RentsColors.primaryBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: RentsColors.bgLightBlue,
      child: const Center(
        child: Icon(
          Icons.school_outlined,
          size: 40,
          color: RentsColors.grayMedium,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.school_outlined,
            size: 64,
            color: RentsColors.grayMedium,
          ),
          const SizedBox(height: 12),
          Text(
            _filterStatus == 'all'
                ? 'Không có khóa học nào'
                : 'Không có khóa học phù hợp',
            style: const TextStyle(color: RentsColors.grayDark, fontSize: 15),
          ),
        ],
      ),
    );
  }

  String _courseDuration(Map<String, dynamic> course) {
    final duration = (course['duration'] ?? '').toString().trim();
    return duration.isEmpty ? 'Chưa cập nhật' : '$duration buổi';
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
