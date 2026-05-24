import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import 'schedule_screen.dart';
import 'room_management_screen.dart';
import 'student_management_screen.dart';
import 'course_management_screen.dart';
import 'settings_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabAnimController;

  Widget _getScreen(int index) {
    switch (index) {
      case 0: return const ScheduleScreen();
      case 1: return const RoomManagementScreen();
      case 2: return const StudentManagementScreen();
      case 3: return const CourseManagementScreen();
      case 4: return SettingsScreen(onNavigate: (i) => setState(() => _selectedIndex = i));
      default: return const ScheduleScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      body: _getScreen(_selectedIndex),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: RentsColors.bgLightBlue,
        boxShadow: [
          BoxShadow(
            color: RentsColors.primaryBlue.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.calendar_month_rounded,
                Icons.calendar_month,
                'Lịch tập',
              ),
              _buildNavItem(
                1,
                Icons.meeting_room_rounded,
                Icons.meeting_room_outlined,
                'Phòng',
              ),
              _buildNavItem(
                2,
                Icons.people_rounded,
                Icons.people_outline_rounded,
                'Học viên',
              ),
              _buildNavItem(
                3,
                Icons.school_rounded,
                Icons.school_outlined,
                'Khóa học',
              ),
              _buildNavItem(
                4,
                Icons.settings_rounded,
                Icons.settings_outlined,
                'Cài đặt',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData selectedIcon,
    IconData unselectedIcon,
    String label, {
    bool isPrimary = false,
  }) {
    final isSelected = _selectedIndex == index;

    if (isPrimary) {
      return GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                child: isSelected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected
                  ? RentsColors.primaryBlue
                  : RentsColors.grayDark,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? RentsColors.primaryBlue
                    : RentsColors.grayDark,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
