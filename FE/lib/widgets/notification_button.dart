import 'package:flutter/material.dart';
import '../theme/rents_colors.dart';
import '../utils/globals.dart';
import '../screens/admin/notifications_screen.dart';

class NotificationButton extends StatelessWidget {
  const NotificationButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: globalUnreadCount,
      builder: (context, unreadCount, child) {
        return IconButton(
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            backgroundColor: RentsColors.accentGreen,
            child: const Icon(
              Icons.notifications_none_rounded,
              color: RentsColors.primaryBlue,
            ),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            fetchGlobalNotifications();
          },
        );
      },
    );
  }
}
