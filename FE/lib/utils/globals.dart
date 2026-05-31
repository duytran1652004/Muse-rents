import 'package:flutter/foundation.dart';
import 'dart:convert';
import '../services/api_service.dart';

final ValueNotifier<int> globalUnreadCount = ValueNotifier<int>(0);
final ValueNotifier<Map<String, dynamic>?> latestNotification = ValueNotifier(null);
DateTime? _lastNotifTime;

Future<void> fetchGlobalNotifications({bool isInit = false}) async {
  try {
    final resCount = await ApiService.get('/notifications/unread-count');
    if (resCount.statusCode == 200) {
      final data = json.decode(resCount.body);
      globalUnreadCount.value = data['count'] ?? 0;
    }

    final res = await ApiService.get('/notifications');
    if (res.statusCode == 200) {
      final List<dynamic> notifs = json.decode(res.body);
      if (notifs.isNotEmpty) {
        final latest = notifs.first;
        final latestTime = DateTime.parse(latest['created_at']);
        
        if (isInit) {
          _lastNotifTime = latestTime;
        } else {
          if (_lastNotifTime == null || latestTime.isAfter(_lastNotifTime!)) {
            _lastNotifTime = latestTime;
            latestNotification.value = null; // force notify
            latestNotification.value = latest;
          }
        }
      }
    }
  } catch (_) {}
}
