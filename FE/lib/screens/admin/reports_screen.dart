import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';
import '../../utils/booking_date_utils.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _recentBookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final statsRes = await ApiService.get('/reports/dashboard');
      final bookingsRes = await ApiService.get('/bookings');
      if (mounted) {
        setState(() {
          if (statsRes.statusCode == 200) _stats = json.decode(statsRes.body);
          if (bookingsRes.statusCode == 200) {
            final all = json.decode(bookingsRes.body) as List;
            _recentBookings = all.take(5).toList();
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: RentsColors.primaryBlue,
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Revenue highlight
                    _buildRevenueCard(),
                    const SizedBox(height: 16),
                    // Stats grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: [
                        _buildStatCard(
                          'Booking mới',
                          '${_stats['newBookings'] ?? 0}',
                          Icons.book_online,
                          RentsColors.accentOrange,
                        ),
                        _buildStatCard(
                          'Học viên',
                          '${_stats['students'] ?? 0}',
                          Icons.people,
                          RentsColors.accentGreen,
                        ),
                        _buildStatCard(
                          'Phòng tập',
                          '${_stats['rooms'] ?? 0}',
                          Icons.meeting_room,
                          RentsColors.primaryBlue,
                        ),
                        _buildStatCard(
                          'Hoàn thành',
                          '${_stats['completedBookings'] ?? 0}',
                          Icons.event_available,
                          RentsColors.primaryBlueDark,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Recent activity
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hoạt động gần đây',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: RentsColors.black,
                          ),
                        ),
                        TextButton(
                          onPressed: _fetchData,
                          child: const Text(
                            'Làm mới',
                            style: TextStyle(color: RentsColors.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ..._recentBookings.map((b) => _buildActivityItem(b)),
                    if (_recentBookings.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text(
                            'Chưa có hoạt động nào',
                            style: TextStyle(color: RentsColors.grayDark),
                          ),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
        centerTitle: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Báo cáo & Thống kê',
        style: TextStyle(
          color: RentsColors.black,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: RentsColors.primaryBlue),
          onPressed: _fetchData,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: RentsColors.grayLight),
      ),
    );
  }

  Widget _buildRevenueCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: RentsColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: RentsColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng doanh thu',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatPrice(_stats['revenue'] ?? 0)}đ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Tháng này',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: RentsColors.grayDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> booking) {
    final statusColor = _statusColor(booking['status']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: RentsColors.softCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.receipt_long, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['student_name'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: RentsColors.black,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '${booking['room_name'] ?? 'N/A'} • ${_formatDate(booking['booking_date'])}',
                  style: const TextStyle(
                    color: RentsColors.grayDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (booking['price'] != null)
            Text(
              '${booking['price']}đ',
              style: const TextStyle(
                color: RentsColors.primaryBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'pending':
        return RentsColors.accentOrange;
      case 'confirmed':
        return RentsColors.accentGreen;
      case 'completed':
        return RentsColors.primaryBlue;
      case 'cancelled':
        return RentsColors.accentRed;
      default:
        return RentsColors.grayDark;
    }
  }

  String _formatDate(dynamic d) {
    return formatBookingDateShort(d);
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final num p = price is num ? price : num.tryParse(price.toString()) ?? 0;
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)} triệu';
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(0)}K';
    return p.toString();
  }
}
