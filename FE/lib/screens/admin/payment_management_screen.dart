import 'package:flutter/material.dart';
import 'dart:convert';
import '../../theme/rents_colors.dart';
import '../../services/api_service.dart';

class PaymentManagementScreen extends StatefulWidget {
  const PaymentManagementScreen({super.key});

  @override
  State<PaymentManagementScreen> createState() => _PaymentManagementScreenState();
}

class _PaymentManagementScreenState extends State<PaymentManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _enrollments = [];
  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchEnrollments();
  }

  Future<void> _fetchEnrollments() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get('/enrollments');
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        setState(() {
          _enrollments = data;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredEnrollments {
    return _enrollments.where((e) {
      // Search
      final studentName = (e['student_name'] ?? '').toString().toLowerCase();
      final courseName = (e['course_name'] ?? e['class_name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      if (!studentName.contains(query) && !courseName.contains(query)) return false;

      // Filter
      if (_statusFilter == 'all') return true;
      
      String currentType = e['payment_type'] ?? '100%';
      bool status1 = e['payment_status_1'] == 'completed';
      bool status2 = e['payment_status_2'] == 'completed';
      
      if (_statusFilter == 'unpaid') {
        return !status1;
      } else if (_statusFilter == 'paid_1') {
        return currentType == '50%' && status1 && !status2;
      } else if (_statusFilter == 'paid_all') {
        return (currentType == '100%' && status1) || (currentType == '50%' && status1 && status2);
      }
      return true;
    }).toList();
  }

  String _formatCurrency(double amount) {
    String value = amount.toStringAsFixed(0);
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String mathFunc(Match match) => '${match[1]}.';
    return '${value.replaceAllMapped(reg, mathFunc)} ₫';
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      return '';
    }
  }

  void _showPaymentDialog(dynamic enrollment) {
    String currentType = enrollment['payment_type'] ?? '100%';
    bool originalStatus1 = enrollment['payment_status_1'] == 'completed';
    bool originalStatus2 = enrollment['payment_status_2'] == 'completed';
    bool status1 = originalStatus1;
    bool status2 = originalStatus2;
    bool isSaving = false;
    double price = double.tryParse(enrollment['course_price']?.toString() ?? enrollment['price_per_class']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String amount1Text = currentType == '100%' ? _formatCurrency(price) : _formatCurrency(price / 2);
            String amount2Text = _formatCurrency(price / 2);

            return Container(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
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
                      width: 40, height: 5,
                      decoration: BoxDecoration(
                        color: RentsColors.grayLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('XÁC NHẬN THANH TOÁN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: RentsColors.primaryBlue)),
                  const SizedBox(height: 8),
                  Text('Học viên: ${enrollment['student_name'] ?? 'Ẩn danh'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('Khóa học: ${enrollment['course_name'] ?? enrollment['class_name'] ?? 'Khóa học'}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  const Text('Hình thức thanh toán:', style: TextStyle(fontWeight: FontWeight.w700, color: RentsColors.grayDark)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Thanh toán 100%', style: TextStyle(fontSize: 14)),
                          value: '100%',
                          groupValue: currentType,
                          activeColor: RentsColors.primaryBlue,
                          contentPadding: EdgeInsets.zero,
                          onChanged: originalStatus1 ? null : (val) {
                            if (val != null) setModalState(() => currentType = val);
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Chia 2 đợt (50%)', style: TextStyle(fontSize: 14)),
                          value: '50%',
                          groupValue: currentType,
                          activeColor: RentsColors.primaryBlue,
                          contentPadding: EdgeInsets.zero,
                          onChanged: originalStatus1 ? null : (val) {
                            if (val != null) setModalState(() => currentType = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Trạng thái:', style: TextStyle(fontWeight: FontWeight.w700, color: RentsColors.grayDark)),
                  const SizedBox(height: 8),
                  if (currentType == '100%')
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Số tiền cần thu:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                              const SizedBox(width: 8),
                              Text(amount1Text, style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          if (originalStatus1) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 20),
                                const SizedBox(width: 6),
                                Expanded(child: Text('Đã thu (${_formatDateTime(enrollment['payment_date_1'])})', style: const TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    SwitchListTile(
                      title: Row(
                        children: [
                          const Text('Thanh toán đợt 1', style: TextStyle(fontWeight: FontWeight.w600)),
                          if (originalStatus1)
                            Expanded(child: Text(' (${_formatDateTime(enrollment['payment_date_1'])})', style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 13), textAlign: TextAlign.right)),
                        ]
                      ),
                      subtitle: Text('Số tiền: $amount1Text', style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold)),
                      value: status1,
                      activeColor: const Color(0xFF2ECC71),
                      contentPadding: EdgeInsets.zero,
                      onChanged: originalStatus1 ? null : (val) {
                        setModalState(() {
                          status1 = val;
                          if (!status1) {
                            status2 = false; // Tự động bỏ check đợt 2 nếu đợt 1 chưa thanh toán
                          }
                        });
                      },
                    ),
                  if (currentType == '50%')
                    SwitchListTile(
                      title: Row(
                        children: [
                          const Text('Thanh toán đợt 2', style: TextStyle(fontWeight: FontWeight.w600)),
                          if (originalStatus2)
                            Expanded(child: Text(' (${_formatDateTime(enrollment['payment_date_2'])})', style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 13), textAlign: TextAlign.right)),
                        ]
                      ),
                      subtitle: Text('Số tiền: $amount2Text', style: const TextStyle(color: RentsColors.primaryBlue, fontWeight: FontWeight.bold)),
                      value: status2,
                      activeColor: const Color(0xFF2ECC71),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (originalStatus2 || !status1) ? null : (val) => setModalState(() => status2 = val),
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (isSaving || (currentType == '100%' && originalStatus1) || (currentType == '50%' && originalStatus1 && originalStatus2)) ? null : () async {
                        setModalState(() => isSaving = true);
                        try {
                          final body = {
                            'payment_type': currentType,
                            'payment_status_1': currentType == '100%' ? 'completed' : (status1 ? 'completed' : 'pending'),
                            'payment_status_2': currentType == '100%' ? 'pending' : (status2 ? 'completed' : 'pending'),
                          };
                          final res = await ApiService.put('/enrollments/${enrollment['id']}/payment', body);
                          if (res.statusCode == 200 && mounted) {
                            Navigator.pop(context);
                            _fetchEnrollments();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Cập nhật thanh toán thành công')),
                            );
                          } else {
                            setModalState(() => isSaving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lỗi cập nhật'), backgroundColor: RentsColors.accentRed),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSaving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RentsColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('XÁC NHẬN THANH TOÁN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentStatus(dynamic e) {
    String currentType = e['payment_type'] ?? '100%';
    bool status1 = e['payment_status_1'] == 'completed';
    bool status2 = e['payment_status_2'] == 'completed';

    if (currentType == '100%') {
      return Row(
        children: [
          Icon(status1 ? Icons.check_circle : Icons.pending, color: status1 ? const Color(0xFF2ECC71) : RentsColors.accentRed, size: 16),
          const SizedBox(width: 4),
          Text(status1 ? 'Đã thu 100%' : 'Chưa thu', style: TextStyle(color: status1 ? const Color(0xFF2ECC71) : RentsColors.accentRed, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      );
    } else {
      return Row(
        children: [
          Icon(status1 ? Icons.check_circle : Icons.pending, color: status1 ? const Color(0xFF2ECC71) : RentsColors.accentRed, size: 16),
          const SizedBox(width: 4),
          Text('Đợt 1', style: TextStyle(color: status1 ? const Color(0xFF2ECC71) : RentsColors.accentRed, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 12),
          Icon(status2 ? Icons.check_circle : Icons.pending, color: status2 ? const Color(0xFF2ECC71) : RentsColors.accentRed, size: 16),
          const SizedBox(width: 4),
          Text('Đợt 2', style: TextStyle(color: status2 ? const Color(0xFF2ECC71) : RentsColors.accentRed, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      );
    }
  }

  Widget _buildTopControls() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Tìm học viên, khóa học...',
            prefixIcon: const Icon(Icons.search, color: RentsColors.primaryBlue),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Tất cả trạng thái', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownMenuItem(value: 'unpaid', child: Text('Chưa thanh toán', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownMenuItem(value: 'paid_1', child: Text('Đã thu đợt 1 (50%)', style: TextStyle(fontWeight: FontWeight.w600))),
                DropdownMenuItem(value: 'paid_all', child: Text('Đã thu đủ (100%)', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _statusFilter = val);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEnrollments;

    return Scaffold(
      backgroundColor: RentsColors.bgLightBlue,
      appBar: AppBar(
        title: const Text('QUẢN LÝ THANH TOÁN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: RentsColors.primaryBlue,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
          : RefreshIndicator(
              onRefresh: _fetchEnrollments,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildTopControls(),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final e = filtered[index];
                          double price = double.tryParse(e['course_price']?.toString() ?? e['price_per_class']?.toString() ?? '0') ?? 0;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: RentsColors.softCardShadow,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showPaymentDialog(e),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40, height: 40,
                                            decoration: BoxDecoration(
                                              color: RentsColors.primaryBlue.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.person, color: RentsColors.primaryBlue),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(e['student_name'] ?? 'Ẩn danh', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                                Text((e['enrollment_date'] ?? '').split('T')[0], style: const TextStyle(color: RentsColors.grayDark, fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formatCurrency(price),
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: RentsColors.primaryBlue),
                                          ),
                                        ],
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        child: Divider(height: 1),
                                      ),
                                      Text('Khóa học: ${e['course_name'] ?? e['class_name'] ?? 'Khóa học'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      const SizedBox(height: 8),
                                      _buildPaymentStatus(e),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
