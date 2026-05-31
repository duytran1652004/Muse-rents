import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import 'edit_item_screen.dart';
import 'room_detail_sheet.dart';
import '../../widgets/notification_button.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _rooms = [];
  bool _isLoading = true;
  String _filterStatus = 'all';
  final TextEditingController _searchController = TextEditingController();
  static const String baseUrl = ApiService.serverUrl;

  final List<Map<String, dynamic>> _filters = [
    {'key': 'all', 'label': 'Tất cả'},
    {'key': 'available', 'label': 'Còn trống'},
    {'key': 'occupied', 'label': 'Đang dùng'},
    {'key': 'maintenance', 'label': 'Bảo trì'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchRooms();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get('/rooms');
      if (response.statusCode == 200) {
        setState(() {
          _rooms = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredRooms {
    final query = _searchController.text.toLowerCase();
    return _rooms.where((r) {
      final s = r['status'] ?? 'available';
      bool matchStatus = true;
      if (_filterStatus == 'available') {
        matchStatus = s == 'available' || s == 'active';
      } else if (_filterStatus == 'occupied') {
        matchStatus = s == 'occupied' || s == 'booked';
      } else if (_filterStatus == 'maintenance') {
        matchStatus = s == 'maintenance';
      }
      
      final name = (r['name'] ?? '').toString().toLowerCase();
      final facilities = (r['facilities'] ?? '').toString().toLowerCase();
      final matchSearch = name.contains(query) || facilities.contains(query);
      
      return matchStatus && matchSearch;
    }).toList();
  }

  Future<void> _openEdit(Map<String, dynamic>? room) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditItemScreen(type: 'room', existingData: room),
      ),
    );
    if (result == true) _fetchRooms();
  }

  void _showRoomDetail(Map<String, dynamic> room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomDetailSheet(
        room: room,
        baseUrl: baseUrl,
        onEdit: () {
          Navigator.pop(context);
          _openEdit(room);
        },
        onStatusChange: (id, status) async {
          await ApiService.put('/rooms/$id', {'status': status});
          _fetchRooms();
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
                else if (_filteredRooms.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  _buildRoomGrid(),
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
        'QUẢN LÝ PHÒNG',
        style: TextStyle(
          color: RentsColors.black,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
          onPressed: _fetchRooms,
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
              hintText: 'Tìm kiếm phòng...',
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
              children: _filters.map((f) {
                final isActive = _filterStatus == f['key'];
                return GestureDetector(
                  onTap: () => setState(() => _filterStatus = f['key'] as String),
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
                      f['label'] as String,
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

  Widget _buildRoomGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildRoomCard(_filteredRooms[i]),
          ),
          childCount: _filteredRooms.length,
        ),
      ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final imageUrl = room['image_url'];
    final status = room['status'] ?? 'available';
    final isAvailable = status == 'available' || status == 'active';
    final isMaintenance = status == 'maintenance';
    final statusColor = isAvailable
        ? RentsColors.accentGreen
        : (isMaintenance ? RentsColors.accentOrange : RentsColors.accentRed);
    final statusLabel = isAvailable
        ? 'Còn trống'
        : (isMaintenance ? 'Bảo trì' : 'Đang dùng');

    return GestureDetector(
      onTap: () => _showRoomDetail(room),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: RentsColors.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (Fixed aspect ratio for horizontal layout)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            '$baseUrl$imageUrl',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  // Status Badge
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
                  // Occupant indicator
                  if (!isAvailable && room['current_tenant'] != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
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
                          room['current_tenant'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info (Only takes as much space as it needs, no extra whitespace)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room['name'] ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: RentsColors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  if (room['facilities'] != null && room['facilities'].toString().isNotEmpty)
                    Text(
                      'Thiết bị: ${room['facilities']}',
                      style: const TextStyle(
                        color: RentsColors.grayDark,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  const Text(
                    'TG khả dụng: 9:00 - 21:00',
                    style: TextStyle(
                      color: RentsColors.grayDark,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 16,
                        color: RentsColors.grayDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${room['capacity'] ?? 0} người',
                        style: const TextStyle(
                          color: RentsColors.grayDark,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatPrice(room['price_per_hour']),
                        style: const TextStyle(
                          color: RentsColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
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
          Icons.meeting_room_outlined,
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
            Icons.meeting_room_outlined,
            size: 64,
            color: RentsColors.grayMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'Không có phòng nào',
            style: TextStyle(color: RentsColors.grayDark, fontSize: 15),
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
}
