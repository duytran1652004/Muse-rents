import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import 'dart:async';
import 'dart:convert';
import '../../services/api_service.dart';
import '../../utils/globals.dart';
import 'schedule_screen.dart';
import 'room_management_screen.dart';
import 'student_management_screen.dart';
import 'course_management_screen.dart';
import 'settings_screen.dart';
import 'notifications_screen.dart';
import 'student_dashboard_screen.dart';
import 'student_home_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabAnimController;
  late final List<Widget> _screens = [
    const ScheduleScreen(),
    const RoomManagementScreen(),
    const StudentManagementScreen(),
    const CourseManagementScreen(),
    SettingsScreen(onNavigate: (i) => setState(() => _selectedIndex = i)),
    const StudentDashboardScreen(),
    const StudentHomeScreen(),
  ];

  int _lastUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    fetchGlobalNotifications(isInit: true); // Lấy lần đầu
    fetchUserProfile(); // Lấy role
    latestNotification.addListener(_onLatestNotificationChanged);
  }

  void _onLatestNotificationChanged() {
    final notif = latestNotification.value;
    if (notif != null) {
      _showNotificationPopup(notif);
    }
  }

  void _showNotificationPopup(Map<String, dynamic> notif) {
    if (!mounted) return;
    final message = notif['message'] ?? 'Bạn có thông báo mới';
    
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -100.0, end: 0.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () {
                overlayEntry?.remove();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: RentsColors.primaryBlue,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    Future.delayed(const Duration(seconds: 4), () {
      overlayEntry?.remove();
    });
  }

  @override
  void dispose() {
    latestNotification.removeListener(_onLatestNotificationChanged);
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: globalRole,
      builder: (context, role, child) {
        final isTeacher = role == 'teacher';
        final isStudent = role == 'student';
        
        Widget currentScreen;
        if (isTeacher) {
          if (_selectedIndex == 0) currentScreen = _screens[0];
          else if (_selectedIndex == 1) currentScreen = _screens[2];
          else currentScreen = _screens[4];
        } else if (isStudent) {
          if (_selectedIndex == 0) currentScreen = _screens[5]; // StudentDashboardScreen
          else if (_selectedIndex == 1) currentScreen = _screens[3]; // CourseManagementScreen
          else if (_selectedIndex == 2) currentScreen = _screens[2]; // StudentManagementScreen (Giáo viên)
          else currentScreen = _screens[4]; // SettingsScreen
        } else {
          currentScreen = _screens[_selectedIndex];
        }
        
        return Scaffold(
          extendBody: false,
          backgroundColor: RentsColors.bgLightBlue,
          body: currentScreen,
          bottomNavigationBar: _buildBottomNav(isTeacher, isStudent),
        );
      },
    );
  }

  Widget _buildBottomNav(bool isTeacher, bool isStudent) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: RentsColors.primaryBlue.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: isTeacher ? [
                _buildNavItem(0, Icons.calendar_month_rounded, Icons.calendar_month, 'Lớp học'),
                _buildNavItem(1, Icons.people_rounded, Icons.people_outline_rounded, 'Học viên'),
                _buildNavItem(2, Icons.settings_rounded, Icons.settings_outlined, 'Cài đặt'),
              ] : isStudent ? [
                _buildNavItem(0, Icons.school_rounded, Icons.school_outlined, 'Khóa của tôi'),
                _buildNavItem(1, Icons.library_books_rounded, Icons.library_books_outlined, 'Tham khảo'),
                _buildNavItem(2, Icons.people_rounded, Icons.people_outline_rounded, 'Giáo viên'),
                _buildNavItem(3, Icons.settings_rounded, Icons.settings_outlined, 'Cài đặt'),
              ] : [
                _buildNavItem(0, Icons.calendar_month_rounded, Icons.calendar_month, 'Lịch tập'),
                _buildNavItem(1, Icons.meeting_room_rounded, Icons.meeting_room_outlined, 'Phòng'),
                _buildNavItem(2, Icons.people_rounded, Icons.people_outline_rounded, 'Học viên'),
                _buildNavItem(3, Icons.school_rounded, Icons.school_outlined, 'Khóa học'),
                _buildNavItem(4, Icons.settings_rounded, Icons.settings_outlined, 'Cài đặt'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
    String label,
  ) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected ? RentsColors.primaryGradient : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? RentsColors.cardShadow : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? Colors.white : RentsColors.grayDark,
              size: 22,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
