import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/decorated_background.dart';
import 'dart:convert';
import 'room_management_screen.dart';
import 'student_management_screen.dart';
import 'course_management_screen.dart';
import 'booking_management_screen.dart';
import 'reports_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  Map<String, dynamic> _stats = {
    'rooms': 0,
    'students': 0,
    'newBookings': 0,
    'revenue': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await ApiService.get('/reports/dashboard');
      if (response.statusCode == 200) {
        setState(() {
          _stats = json.decode(response.body);
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ADMIN DASHBOARD', style: TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue), onPressed: _fetchStats),
          IconButton(
            icon: const Icon(Icons.logout, color: RentsColors.primaryBlue),
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
        ],
      ),
      body: DecoratedBackground(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thống kê hệ thống',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: RentsColors.black),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard('Phòng tập', _stats['rooms'].toString(), Icons.meeting_room, RentsColors.primaryBlue),
                _buildStatCard('Học viên', _stats['students'].toString(), Icons.people, RentsColors.accentGreen),
                _buildStatCard('Booking mới', _stats['newBookings'].toString(), Icons.notifications_active, RentsColors.accentOrange),
                _buildStatCard('Doanh thu', '${_stats['revenue']}đ', Icons.attach_money, RentsColors.primaryBlueDark),
              ],
            ),
            const SizedBox(height: 40),
            const Text(
              'Quản lý nhanh',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: RentsColors.black),
            ),
            const SizedBox(height: 15),
            _buildManagementTile('QUẢN LÝ PHÒNG/STUDIO', Icons.room_preferences, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const RoomManagementScreen()));
            }),
            _buildManagementTile('QUẢN LÝ HỌC VIÊN', Icons.person_search, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const StudentManagementScreen()));
            }),
            _buildManagementTile('QUẢN LÝ KHÓA HỌC', Icons.library_books, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const CourseManagementScreen()));
            }),
            _buildManagementTile('Quản lý Lịch tập/Lớp học', Icons.event_note, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingManagementScreen()));
            }),
            _buildManagementTile('Báo cáo doanh thu', Icons.bar_chart, () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
            }),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: RentsColors.surfaceBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: RentsColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: RentsColors.grayDark, fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildManagementTile(String title, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: RentsColors.surfaceBlueSoft,
        borderRadius: BorderRadius.circular(15),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: ListTile(
        leading: Icon(icon, color: RentsColors.primaryBlue),
        title: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, color: RentsColors.black)),
        trailing: const Icon(Icons.chevron_right, color: RentsColors.grayMedium),
        onTap: onTap,
      ),
    );
  }
}
