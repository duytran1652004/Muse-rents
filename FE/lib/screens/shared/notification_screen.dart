import 'package:flutter/material.dart';
import '../../theme/rents_colors.dart';
import '../../widgets/decorated_background.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('THÔNG BÁO', style: TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold)),
      ),
      body: DecoratedBackground(
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildNotificationCard('Booking thành công', 'Bạn đã đặt phòng Studio 1 vào lúc 18:00 - 20:00 ngày 20/05.', 'booking'),
          _buildNotificationCard('Sắp đến giờ tập', 'Chỉ còn 30 phút nữa là đến giờ tập của bạn tại Studio 2.', 'alert'),
        ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(String title, String message, String type) {
    IconData iconData = Icons.notifications;
    Color iconColor = RentsColors.primaryBlue;

    if (type == 'booking') {
      iconData = Icons.book_online;
      iconColor = RentsColors.accentGreen;
    } else if (type == 'alert') {
      iconData = Icons.warning;
      iconColor = RentsColors.accentOrange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: RentsColors.surfaceBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(message),
      ),
    );
  }
}
