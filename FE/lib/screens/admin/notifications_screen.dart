import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/booking_date_utils.dart';
import '../../utils/globals.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  Set<dynamic> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/notifications');
      if (res.statusCode == 200 && mounted) {
        setState(() {
          _notifications = json.decode(res.body);
          _isLoading = false;
        });
        // Mark all as read
        () async {
          try {
            await ApiService.post('/notifications/mark-all-read', {});
            fetchGlobalNotifications();
          } catch (_) {}
        }();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNotification(dynamic id) async {
    try {
      final res = await ApiService.delete('/notifications/$id');
      if (res.statusCode == 200) {
        setState(() {
          _notifications.removeWhere((n) => n['id'] == id);
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteAllNotifications() async {
    try {
      final res = await ApiService.post('/notifications/delete-multiple', {'ids': 'all'});
      if (res.statusCode == 200) {
        setState(() {
          _notifications.clear();
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteSelectedNotifications() async {
    if (_selectedIds.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa ${_selectedIds.length} thông báo đã chọn?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('HỦY', style: TextStyle(color: RentsColors.grayDark))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('XÓA', style: TextStyle(color: RentsColors.accentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final res = await ApiService.post('/notifications/delete-multiple', {'ids': _selectedIds.toList()});
      if (res.statusCode == 200) {
        setState(() {
          _notifications.removeWhere((n) => _selectedIds.contains(n['id']));
          _selectedIds.clear();
          _isSelectionMode = false;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
        leading: _isSelectionMode 
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); }))
            : const BackButton(),
        title: Text(_isSelectionMode ? 'Đã chọn ${_selectedIds.length}' : 'THÔNG BÁO', style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: RentsColors.primaryBlue),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
              onPressed: _fetchNotifications,
            ),
          if (_notifications.isNotEmpty && !_isSelectionMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.delete_sweep_rounded, color: RentsColors.accentRed),
              onSelected: (value) {
                if (value == 'select') {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedIds.clear();
                  });
                } else if (value == 'all') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Xóa tất cả', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text('Bạn có chắc muốn xóa toàn bộ thông báo không?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('HỦY', style: TextStyle(color: RentsColors.grayDark))),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _deleteAllNotifications();
                          },
                          child: const Text('XÓA', style: TextStyle(color: RentsColors.accentRed, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'select', child: Text('Chọn thông báo để xóa')),
                const PopupMenuItem(value: 'all', child: Text('Xóa tất cả', style: TextStyle(color: RentsColors.accentRed))),
              ],
            ),
          if (_isSelectionMode && _selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: RentsColors.accentRed),
              onPressed: _deleteSelectedNotifications,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (_, i) => _buildNotifCard(_notifications[i]),
                ),
    );
  }

  Widget _buildNotifCard(Map<String, dynamic> notif) {
    if (notif['booking'] != null) {
      return _buildBookingNotifCard(notif);
    }
    if (notif['class_info'] != null) {
      return _buildClassNotifCard(notif);
    }
    if (notif['type'] == 'payment') {
      return _buildPaymentNotifCard(notif);
    }

    return _buildRegularCard(notif);
  }

  Widget _buildRegularCard(Map<String, dynamic> notif) {
    final isRead = notif['is_read'] == true || notif['is_read'] == 1;
    final type = notif['type'] ?? 'alert';
    final typeColor = _typeColor(type);
    final typeIcon = _typeIcon(type);

    final card = GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedIds.contains(notif['id'])) _selectedIds.remove(notif['id']);
            else _selectedIds.add(notif['id']);
          });
        } else {
          setState(() {
            notif['is_read'] = 1;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : RentsColors.primaryBlue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isRead ? Colors.transparent : RentsColors.primaryBlue.withValues(alpha: 0.15)),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(typeIcon, color: typeColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif['title'] ?? '',
                        style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.w800, color: RentsColors.black, fontSize: 14),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: RentsColors.primaryBlue, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notif['message'] ?? '', style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, height: 1.4)),
                const SizedBox(height: 6),
                Text(_formatDate(notif['created_at']), style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ));

    if (_isSelectionMode) {
      final isSelected = _selectedIds.contains(notif['id']);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: RentsColors.primaryBlue,
              onChanged: (val) {
                setState(() {
                  if (val == true) _selectedIds.add(notif['id']);
                  else _selectedIds.remove(notif['id']);
                });
              },
            ),
            Expanded(child: card),
          ],
        ),
      );
    }

    return Dismissible(
      key: ValueKey(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: RentsColors.accentRed, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notif['id']),
      child: card,
    );
  }

  Widget _buildPaymentNotifCard(Map<String, dynamic> notif) {
    final msg = notif['message'] ?? '';
    final lines = msg.split('\n');
    
    // Fallback if it is an old flat string format
    if (lines.length < 4) {
      return _buildRegularCard(notif);
    }

    String studentName = 'Học viên';
    String courseName = 'Khóa học';
    String phase = '';
    String amount = '';
    
    String timeStr = '';
    
    for (var line in lines) {
      if (line.startsWith('Học viên: ')) studentName = line.replaceFirst('Học viên: ', '');
      if (line.startsWith('Khóa học: ')) courseName = line.replaceFirst('Khóa học: ', '');
      if (line.startsWith('Thanh toán: ')) phase = line.replaceFirst('Thanh toán: ', '');
      if (line.startsWith('Số tiền: ')) amount = line.replaceFirst('Số tiền: ', '');
      if (line.startsWith('Thời gian: ')) timeStr = line.replaceFirst('Thời gian: ', '');
    }

    final isRead = notif['is_read'] == true || notif['is_read'] == 1;

    final card = GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedIds.contains(notif['id'])) _selectedIds.remove(notif['id']);
            else _selectedIds.add(notif['id']);
          });
        } else {
          setState(() {
            notif['is_read'] = 1;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : RentsColors.primaryBlue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isRead ? Colors.transparent : RentsColors.primaryBlue.withValues(alpha: 0.2)),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments, size: 16, color: RentsColors.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    notif['title'] ?? 'Xác nhận thanh toán',
                    style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(_formatDate(notif['created_at']), style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.bold)),
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: RentsColors.primaryBlue, shape: BoxShape.circle),
                  ),
                ]
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: RentsColors.grayLight),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: RentsColors.bgLightBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.receipt_long, color: RentsColors.primaryBlue, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              courseName,
                              style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: RentsColors.accentGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              phase,
                              style: const TextStyle(color: RentsColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 14, color: RentsColors.grayDark),
                          const SizedBox(width: 6),
                          Text(studentName, style: const TextStyle(color: RentsColors.grayDark, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, size: 14, color: RentsColors.grayDark),
                          const SizedBox(width: 6),
                          Text(amount, style: const TextStyle(color: RentsColors.accentOrange, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (timeStr.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: RentsColors.grayDark),
                            const SizedBox(width: 6),
                            Text(timeStr, style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (_isSelectionMode) {
      final isSelected = _selectedIds.contains(notif['id']);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: RentsColors.primaryBlue,
              onChanged: (val) {
                setState(() {
                  if (val == true) _selectedIds.add(notif['id']);
                  else _selectedIds.remove(notif['id']);
                });
              },
            ),
            Expanded(child: card),
          ],
        ),
      );
    }

    return Dismissible(
      key: ValueKey(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: RentsColors.accentRed, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notif['id']),
      child: card,
    );
  }

  Widget _buildBookingNotifCard(Map<String, dynamic> notif) {
    final booking = notif['booking'];
    final isRead = notif['is_read'] == true || notif['is_read'] == 1;
    final roomName = booking['room_name'] ?? 'Phòng';
    final customerName = booking['display_name'] ?? booking['guest_name'] ?? booking['student_name'] ?? 'Khách';
    
    String currentStatusStr = booking['status'] ?? 'pending';
    String msg = notif['message'] ?? '';
    if (msg.contains('Đã xác nhận')) currentStatusStr = 'confirmed';
    else if (msg.contains('Đang sử dụng')) currentStatusStr = 'in_progress';
    else if (msg.contains('Hoàn thành')) currentStatusStr = 'completed';
    else if (msg.contains('Đã hủy')) currentStatusStr = 'cancelled';
    else if (msg.contains('Chờ xác nhận')) currentStatusStr = 'pending';

    final statusColor = _getStatusColor(currentStatusStr);
    final statusLabel = _getStatusLabel(currentStatusStr);
    final date = formatBookingDate(booking['booking_date']);
    final startTime = formatTimeStr(booking['start_time']);
    final endTime = formatTimeStr(booking['end_time']);

    final card = GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedIds.contains(notif['id'])) _selectedIds.remove(notif['id']);
            else _selectedIds.add(notif['id']);
          });
        } else {
          setState(() {
            notif['is_read'] = 1;
          });
          _showBookingDetailSheet(booking);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : RentsColors.primaryBlue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isRead ? Colors.transparent : RentsColors.primaryBlue.withValues(alpha: 0.2)),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active, size: 16, color: RentsColors.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    notif['message'] ?? '',
                    style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(_formatDate(notif['created_at']), style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.bold)),
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: RentsColors.primaryBlue, shape: BoxShape.circle),
                  ),
                ]
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: RentsColors.grayLight),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: RentsColors.bgLightBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: booking['room_image_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            ApiService.getImageUrl(booking['room_image_url']),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.meeting_room, color: RentsColors.grayDark, size: 24),
                          ),
                        )
                      : const Icon(Icons.meeting_room, color: RentsColors.grayDark, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              roomName,
                              style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: RentsColors.grayDark),
                          const SizedBox(width: 6),
                          Text(customerName, style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: RentsColors.grayDark),
                          const SizedBox(width: 6),
                          Text('$date | $startTime - $endTime', style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (_isSelectionMode) {
      final isSelected = _selectedIds.contains(notif['id']);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: RentsColors.primaryBlue,
              onChanged: (val) {
                setState(() {
                  if (val == true) _selectedIds.add(notif['id']);
                  else _selectedIds.remove(notif['id']);
                });
              },
            ),
            Expanded(child: card),
          ],
        ),
      );
    }

    return Dismissible(
      key: ValueKey(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: RentsColors.accentRed, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notif['id']),
      child: card,
    );
  }

  Widget _buildClassNotifCard(Map<String, dynamic> notif) {
    final cls = notif['class_info'];
    final isRead = notif['is_read'] == true || notif['is_read'] == 1;
    final className = cls['class_name'] ?? 'Lớp học';
    final instructorName = cls['instructor_name'] ?? 'Chưa xếp giáo viên';
    
    final statusLabel = _getClassStatus(cls);
    final statusColor = _getClassStatusColor(statusLabel);
    
    final schedulesStr = _formatClassSchedules(cls);

    final card = GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          setState(() {
            if (_selectedIds.contains(notif['id'])) _selectedIds.remove(notif['id']);
            else _selectedIds.add(notif['id']);
          });
        } else {
          setState(() {
            notif['is_read'] = 1;
          });
          _showClassDetailSheet(cls);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : RentsColors.primaryBlue.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isRead ? Colors.transparent : RentsColors.primaryBlue.withValues(alpha: 0.2)),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school, size: 16, color: RentsColors.primaryBlue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    notif['message'] ?? '',
                    style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Text(_formatDate(notif['created_at']), style: const TextStyle(color: RentsColors.grayDark, fontSize: 12, fontWeight: FontWeight.bold)),
                if (!isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: RentsColors.primaryBlue, shape: BoxShape.circle),
                  ),
                ]
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: RentsColors.grayLight),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: RentsColors.bgLightBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: cls['course_image_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            ApiService.getImageUrl(cls['course_image_url']),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.school, color: RentsColors.grayDark, size: 24),
                          ),
                        )
                      : const Icon(Icons.school, color: RentsColors.grayDark, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              className,
                              style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: RentsColors.grayDark),
                          const SizedBox(width: 6),
                          Text(instructorName, style: const TextStyle(color: RentsColors.grayDark, fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.access_time, size: 14, color: RentsColors.grayDark),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              schedulesStr,
                              style: const TextStyle(color: RentsColors.grayDark, fontSize: 13),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (_isSelectionMode) {
      final isSelected = _selectedIds.contains(notif['id']);
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              activeColor: RentsColors.primaryBlue,
              onChanged: (val) {
                setState(() {
                  if (val == true) _selectedIds.add(notif['id']);
                  else _selectedIds.remove(notif['id']);
                });
              },
            ),
            Expanded(child: card),
          ],
        ),
      );
    }

    return Dismissible(
      key: ValueKey(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: RentsColors.accentRed, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(notif['id']),
      child: card,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 72, color: RentsColors.grayMedium),
          const SizedBox(height: 12),
          const Text('Không có thông báo nào', style: TextStyle(color: RentsColors.grayDark, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Tất cả thông báo sẽ hiện ở đây', style: TextStyle(color: RentsColors.grayMedium, fontSize: 13)),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'booking': return RentsColors.accentGreen;
      case 'payment': return RentsColors.accentOrange;
      case 'class': return RentsColors.primaryBlue;
      default: return RentsColors.accentRed;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'confirmed': return RentsColors.accentGreen;
      case 'in_progress': return RentsColors.accentOrange;
      case 'completed': return RentsColors.primaryBlue;
      case 'cancelled': return RentsColors.accentRed;
      case 'pending': return RentsColors.grayDark;
      default: return RentsColors.grayMedium;
    }
  }

  String _getStatusLabel(String? status) {
    switch (status) {
      case 'confirmed': return 'Đã xác nhận';
      case 'in_progress': return 'Đang sử dụng';
      case 'completed': return 'Hoàn thành';
      case 'cancelled': return 'Đã hủy';
      case 'pending': return 'Chờ xác nhận';
      default: return status ?? 'Chờ xác nhận';
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'booking': return Icons.book_online;
      case 'payment': return Icons.payments;
      case 'class': return Icons.school;
      default: return Icons.notifications;
    }
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString());
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
      if (diff.inHours < 24) return '${diff.inHours} giờ trước';
      if (diff.inDays < 7) return '${diff.inDays} ngày trước';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  void _showBookingDetailSheet(Map<String, dynamic> booking) {
    final customerName = booking['display_name'] ?? booking['student_name'] ?? booking['guest_name'] ?? 'Khách';
    final roomName = booking['room_name'] ?? 'Phòng';
    final date = formatBookingDate(booking['booking_date']);
    final startTime = formatTimeStr(booking['start_time']);
    final endTime = formatTimeStr(booking['end_time']);
    final statusColor = _getStatusColor(booking['status']);
    final statusLabel = _getStatusLabel(booking['status']);
    final imageUrl = booking['room_image_url'];
    final finalPrice = double.tryParse(booking['final_price']?.toString() ?? booking['price']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: RentsColors.grayMedium, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(color: RentsColors.bgGray, borderRadius: BorderRadius.circular(16)),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          ApiService.getImageUrl(imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                        ),
                      )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      roomName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: RentsColors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: RentsColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(customerName, style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: RentsColors.bgLightBlue, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.access_time_filled, color: RentsColors.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Thời gian', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text('$date | $startTime - $endTime', style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: RentsColors.grayLight)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: RentsColors.accentGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.payments, color: RentsColors.accentGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Giá phòng', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(_formatCurrency(finalPrice), style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

            ],
          ),
        );
      },
    );
  }

  String _getClassStatus(Map<String, dynamic> cls) {
    if (cls['status'] == 'completed') return 'Hoàn thành';
    if (cls['status'] == 'cancelled') return 'Tạm dừng';
    
    final now = DateTime.now();
    final today = _getVietnameseDayName(now.weekday);
    final currentTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final soonTimeStr = '${now.add(const Duration(minutes: 30)).hour.toString().padLeft(2, '0')}:${now.add(const Duration(minutes: 30)).minute.toString().padLeft(2, '0')}';

    bool isHappeningNow = false;
    bool isSoon = false;

    void checkSchedule(String? day, String? start, String? end) {
      if (day == null || start == null || end == null) return;
      if (day != today) return;
      
      final sTime = start.substring(0, 5);
      final eTime = end.substring(0, 5);

      if (currentTime.compareTo(sTime) >= 0 && currentTime.compareTo(eTime) <= 0) {
        isHappeningNow = true;
      } else if (currentTime.compareTo(sTime) < 0 && soonTimeStr.compareTo(sTime) >= 0) {
        isSoon = true;
      }
    }

    checkSchedule(cls['day_of_week'], cls['start_time'], cls['end_time']);
    checkSchedule(cls['day_of_week_2'], cls['start_time_2'], cls['end_time_2']);
    checkSchedule(cls['day_of_week_3'], cls['start_time_3'], cls['end_time_3']);

    if (isHappeningNow) return 'Đang diễn ra';
    if (isSoon) return 'Sắp tới giờ học';
    return 'Đang học';
  }

  Color _getClassStatusColor(String statusLabel) {
    if (statusLabel == 'Đang diễn ra' || statusLabel == 'Sắp tới giờ học') return RentsColors.primaryBlue;
    if (statusLabel == 'Đang học') return RentsColors.accentGreen;
    if (statusLabel == 'Hoàn thành') return RentsColors.primaryBlue;
    return RentsColors.accentOrange;
  }

  String _getVietnameseDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Thứ 2';
      case 2: return 'Thứ 3';
      case 3: return 'Thứ 4';
      case 4: return 'Thứ 5';
      case 5: return 'Thứ 6';
      case 6: return 'Thứ 7';
      case 7: return 'Chủ Nhật';
      default: return '';
    }
  }

  String _translateDay(String day) {
    switch (day) {
      case 'Monday': return 'Thứ Hai';
      case 'Tuesday': return 'Thứ Ba';
      case 'Wednesday': return 'Thứ Tư';
      case 'Thursday': return 'Thứ Năm';
      case 'Friday': return 'Thứ Sáu';
      case 'Saturday': return 'Thứ Bảy';
      case 'Sunday': return 'Chủ Nhật';
      default: return day;
    }
  }

  String _formatClassSchedules(Map<String, dynamic> cls) {
    List<String> schedules = [];
    void addSchedule(String? day, String? start, String? end) {
      if (day != null && start != null && end != null) {
        schedules.add('${_translateDay(day)} (${start.substring(0, 5)} - ${end.substring(0, 5)})');
      }
    }
    addSchedule(cls['day_of_week'], cls['start_time'], cls['end_time']);
    addSchedule(cls['day_of_week_2'], cls['start_time_2'], cls['end_time_2']);
    addSchedule(cls['day_of_week_3'], cls['start_time_3'], cls['end_time_3']);
    return schedules.join(', ');
  }

  void _showClassDetailSheet(Map<String, dynamic> cls) {
    final className = cls['class_name'] ?? 'Lớp học';
    final instructorName = cls['instructor_name'] ?? 'Chưa xếp giáo viên';
    final schedulesStr = _formatClassSchedules(cls);
    final statusLabel = _getClassStatus(cls);
    final statusColor = _getClassStatusColor(statusLabel);
    final completed = cls['completed_sessions'] ?? 0;
    final total = cls['total_sessions'] ?? 0;
    final imageUrl = cls['course_image_url'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: RentsColors.grayMedium, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(color: RentsColors.bgGray, borderRadius: BorderRadius.circular(16)),
                child: imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          ApiService.getImageUrl(imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                        ),
                      )
                    : _buildPlaceholderImage(),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      className,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: RentsColors.black),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 14, color: RentsColors.primaryBlue),
                        const SizedBox(width: 6),
                        Text(instructorName, style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(statusLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: RentsColors.bgLightBlue, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.access_time_filled, color: RentsColors.primaryBlue, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Thời gian', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(schedulesStr, style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: RentsColors.grayLight)),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: RentsColors.accentGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle, color: RentsColors.accentGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tiến độ', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                              const SizedBox(height: 2),
                              Text('$completed / $total buổi', style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (cls['student_names'] != null) ...[
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: RentsColors.grayLight)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: RentsColors.primaryBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
                            child: const Icon(Icons.group, color: RentsColors.primaryBlue, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Học viên', style: TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(cls['student_names'].toString(), style: const TextStyle(color: RentsColors.black, fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.meeting_room, size: 48, color: RentsColors.grayMedium),
        SizedBox(height: 8),
        Text('Chưa có ảnh phòng', style: TextStyle(color: RentsColors.grayDark)),
      ],
    );
  }

  Widget _buildActionButton(String label, Color bgColor, Color textColor, VoidCallback onTap, {bool isOutlined = false}) {
    return SizedBox(
      height: 48,
      child: isOutlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(side: BorderSide(color: textColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(backgroundColor: bgColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ),
    );
  }

  String _formatCurrency(double value) {
    return value.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  Future<void> _updateBookingStatus(dynamic id, String newStatus) async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.put('/bookings/$id', {'status': newStatus});
      if (response.statusCode == 200) {
        _fetchNotifications();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi cập nhật trạng thái')));
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối server')));
    }
  }

  Future<void> _deleteBooking(dynamic id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa lịch tập này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.delete('/bookings/$id');
      if (response.statusCode == 200) {
        _fetchNotifications();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi xóa lịch tập')));
      }
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối server')));
    }
  }
}
