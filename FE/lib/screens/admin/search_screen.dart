import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/booking_date_utils.dart';
import 'student_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _rooms = [];
  List<dynamic> _students = [];
  List<dynamic> _bookings = [];
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    if (q.length >= 2) {
      _doSearch(q);
    } else {
      setState(() {
        _rooms = [];
        _students = [];
        _bookings = [];
      });
    }
  }

  Future<void> _doSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await Future.wait([
        ApiService.get('/rooms?search=$query'),
        ApiService.get('/students?search=$query'),
        ApiService.get('/bookings?search=$query'),
      ]);
      if (mounted) {
        setState(() {
          if (results[0].statusCode == 200)
            _rooms = json.decode(results[0].body);
          if (results[1].statusCode == 200)
            _students = json.decode(results[1].body);
          if (results[2].statusCode == 200)
            _bookings = json.decode(results[2].body);
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: RentsColors.primaryBlue),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Tìm phòng, học viên, lịch tập...',
            hintStyle: TextStyle(color: RentsColors.grayMedium),
            border: InputBorder.none,
          ),
          style: const TextStyle(color: RentsColors.black, fontSize: 16),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: RentsColors.grayDark),
              onPressed: () => _searchController.clear(),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: RentsColors.primaryBlue,
          unselectedLabelColor: RentsColors.grayDark,
          indicatorColor: RentsColors.primaryBlue,
          tabs: [
            Tab(text: 'Phòng (${_rooms.length})'),
            Tab(text: 'Học viên (${_students.length})'),
            Tab(text: 'Lịch (${_bookings.length})'),
          ],
        ),
      ),
      body: _searchController.text.length < 2
          ? _buildHintState()
          : _isSearching
          ? const Center(
              child: CircularProgressIndicator(color: RentsColors.primaryBlue),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRoomResults(),
                _buildStudentResults(),
                _buildBookingResults(),
              ],
            ),
    );
  }

  Widget _buildHintState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 72, color: RentsColors.grayMedium),
          const SizedBox(height: 12),
          const Text(
            'Nhập ít nhất 2 ký tự để tìm kiếm',
            style: TextStyle(color: RentsColors.grayDark, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomResults() {
    if (_rooms.isEmpty) return _emptyResult('Không tìm thấy phòng nào');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (_, i) {
        final r = _rooms[i];
        return _buildResultTile(
          icon: Icons.meeting_room,
          title: r['name'] ?? '',
          subtitle:
              '${r['capacity'] ?? 0} người • ${r['price_per_hour'] ?? 0}/h',
          color: RentsColors.primaryBlue,
        );
      },
    );
  }

  Widget _buildStudentResults() {
    if (_students.isEmpty) return _emptyResult('Không tìm thấy học viên nào');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (_, i) {
        final s = _students[i];
        return _buildResultTile(
          icon: Icons.person,
          title: s['name'] ?? '',
          subtitle: '${s['phone'] ?? ''} • ${s['email'] ?? ''}',
          color: RentsColors.accentGreen,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StudentDetailScreen(student: s)),
          ),
        );
      },
    );
  }

  Widget _buildBookingResults() {
    if (_bookings.isEmpty) return _emptyResult('Không tìm thấy lịch nào');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (_, i) {
        final b = _bookings[i];
        return _buildResultTile(
          icon: Icons.event_note,
          title: '${b['room_name'] ?? 'N/A'} - ${b['student_name'] ?? 'N/A'}',
          subtitle:
              '${_formatDate(b['booking_date'])} | ${formatTimeStr(b['start_time'])} - ${formatTimeStr(b['end_time'])}',
          color: RentsColors.accentOrange,
        );
      },
    );
  }

  Widget _buildResultTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: RentsColors.black,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: RentsColors.grayDark, fontSize: 12),
        ),
        trailing: onTap != null
            ? const Icon(Icons.chevron_right, color: RentsColors.grayMedium)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _emptyResult(String msg) {
    return Center(
      child: Text(
        msg,
        style: const TextStyle(color: RentsColors.grayDark, fontSize: 14),
      ),
    );
  }

  String _formatDate(dynamic d) {
    return formatBookingDate(d);
  }
}
