import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/booking_date_utils.dart';

class RoomDetailSheet extends StatefulWidget {
  final Map<String, dynamic> room;
  final String baseUrl;
  final VoidCallback onEdit;
  final Function(int, String) onStatusChange;

  const RoomDetailSheet({
    super.key,
    required this.room,
    required this.baseUrl,
    required this.onEdit,
    required this.onStatusChange,
  });

  @override
  State<RoomDetailSheet> createState() => _RoomDetailSheetState();
}

class _RoomDetailSheetState extends State<RoomDetailSheet> {
  List<dynamic> _activeBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoomBookings();
  }

  Future<void> _fetchRoomBookings() async {
    try {
      final res = await ApiService.get(
        '/bookings?room_id=${widget.room['id']}',
      );
      if (res.statusCode == 200 && mounted) {
        final all = json.decode(res.body) as List;
        setState(() {
          _activeBookings = all
              .where(
                (b) => b['status'] == 'confirmed' || b['status'] == 'in_progress',
              )
              .toList();
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
    final room = widget.room;
    final status = room['status'] ?? 'available';
    final imageUrl = room['image_url'];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: RentsColors.grayMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: (imageUrl != null && imageUrl.isNotEmpty)
                            ? Image.network(
                                '${widget.baseUrl}$imageUrl',
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPlaceholderImage(),
                              )
                            : _buildPlaceholderImage(),
                      ),
                    ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room['name'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: RentsColors.black,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: widget.onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: RentsColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Stats row
                  Row(
                    children: [
                      _statChip(
                        Icons.people_outline,
                        '${room['capacity'] ?? 0} người',
                        RentsColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        Icons.attach_money,
                        '${_formatPrice(room['price_per_hour'])}/h',
                        RentsColors.accentGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status section
                  const Text(
                    'Trạng thái phòng',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: RentsColors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statusToggle(
                        'available',
                        'Còn trống',
                        RentsColors.accentGreen,
                        status,
                      ),
                      const SizedBox(width: 12),
                      _statusToggle(
                        'maintenance',
                        'Bảo trì',
                        RentsColors.accentOrange,
                        status,
                      ),
                    ],
                  ),
                  // Facilities
                  if (room['facilities'] != null &&
                      room['facilities'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Tiện nghi',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: RentsColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room['facilities'],
                      style: const TextStyle(
                        color: RentsColors.grayDark,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (room['description'] != null &&
                      room['description'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Mô tả',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: RentsColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      room['description'],
                      style: const TextStyle(
                        color: RentsColors.grayDark,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  // Current bookings / tenant info
                  Row(
                    children: [
                      const Text(
                        'Lịch đặt hiện tại',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: RentsColors.black,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _activeBookings.isNotEmpty
                              ? RentsColors.accentOrange.withValues(alpha: 0.12)
                              : RentsColors.accentGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _activeBookings.isNotEmpty
                              ? '${_activeBookings.length} lịch'
                              : 'Rảnh',
                          style: TextStyle(
                            color: _activeBookings.isNotEmpty
                                ? RentsColors.accentOrange
                                : RentsColors.accentGreen,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_activeBookings.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: RentsColors.bgLightBlue,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.event_available,
                            color: RentsColors.accentGreen,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Không có lịch đặt nào',
                            style: TextStyle(color: RentsColors.grayDark),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._activeBookings.map((b) => _buildTenantCard(b)),
                ],
              ),
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

  Widget _buildPlaceholderImage() {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: RentsColors.bgLightBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 64,
              color: RentsColors.primaryBlue.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Chưa có ảnh phòng',
              style: TextStyle(
                color: RentsColors.grayDark.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusToggle(
    String value,
    String label,
    Color color,
    String current,
  ) {
    final isSelected =
        current == value || (value == 'available' && (current == 'active'));
    return Expanded(
      child: GestureDetector(
        onTap: () {
          widget.onStatusChange(widget.room['id'], value);
          Navigator.pop(context);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: isSelected ? 0 : 1),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTenantCard(Map<String, dynamic> booking) {
    Color statusColor = RentsColors.primaryBlue;
    String statusLabel = 'Hoàn thành';
    
    if (booking['status'] == 'confirmed') {
      statusColor = RentsColors.accentGreen;
      statusLabel = 'Đặt trước: ${_formatDate(booking['booking_date'])}';
    } else if (booking['status'] == 'in_progress') {
      statusColor = RentsColors.accentOrange;
      statusLabel = 'Đang sử dụng';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RentsColors.bgLightBlue,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: RentsColors.primaryBlue.withValues(alpha: 0.12),
            child: Text(
              ((booking['display_name'] ?? booking['student_name'] ?? '?')
                      .toString())[0]
                  .toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: RentsColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['display_name'] ?? booking['student_name'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: RentsColors.black,
                  ),
                ),
                Text(
                  '${_formatDate(booking['booking_date'])} | ${formatTimeStr(booking['start_time'])} - ${formatTimeStr(booking['end_time'])}',
                  style: const TextStyle(
                    color: RentsColors.grayDark,
                    fontSize: 12,
                  ),
                ),
                if (booking['guest_phone'] != null &&
                    booking['guest_phone'].toString().isNotEmpty)
                  Text(
                    booking['guest_phone'],
                    style: const TextStyle(
                      color: RentsColors.grayDark,
                      fontSize: 12,
                    ),
                  ),
                if (booking['created_by_name'] != null)
                  Text(
                    'Người tạo: ${booking['created_by_name']}',
                    style: const TextStyle(
                      color: RentsColors.grayDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(0)}K';
    return p.toString();
  }

  String _formatDate(dynamic d) {
    return formatBookingDate(d);
  }
}
