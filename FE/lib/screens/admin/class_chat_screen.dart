import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import '../../services/api_service.dart';
import '../../theme/rents_colors.dart';
import '../../utils/globals.dart';

class ClassChatScreen extends StatefulWidget {
  final int classId;
  final String className;

  const ClassChatScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassChatScreen> createState() => _ClassChatScreenState();
}

class _ClassChatScreenState extends State<ClassChatScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _accessDenied = false;
  Timer? _pollTimer;

  int _myUserId = -1;
  String _myName = '';
  String _myAvatar = '';
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _myUserId = globalUserId.value;
    _init();
  }

  Future<void> _init() async {
    await _fetchMyProfile();
    await _fetchMessages(initial: true);
    // Poll mỗi 3 giây để nhận tin nhắn mới
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_accessDenied) _fetchMessages();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Lấy thông tin người dùng hiện tại (tên, avatar)
  Future<void> _fetchMyProfile() async {
    try {
      final res = await ApiService.get('/auth/me');
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        setState(() {
          _myUserId = data['id'] ?? globalUserId.value;
          _myName = data['full_name'] ?? '';
          _myAvatar = data['avatar_image'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    try {
      final response = await ApiService.get('/classes/${widget.classId}/messages');
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> msgs = json.decode(response.body);
        final bool hasNew = msgs.length != _lastCount;
        setState(() {
          _messages = msgs;
          _lastCount = msgs.length;
          if (initial) _isLoading = false;
        });
        if (initial || hasNew) _scrollToBottom();
      } else if (response.statusCode == 403) {
        setState(() {
          _accessDenied = true;
          _isLoading = false;
        });
      } else if (initial) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (initial && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    // Optimistic UI: thêm tin nhắn tạm thời ngay lập tức
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final tempMsg = {
      'id': tempId,
      'sender_id': _myUserId,
      'message': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'sender_name': _myName.isNotEmpty ? _myName : 'Tôi',
      'sender_avatar': _myAvatar.isNotEmpty ? _myAvatar : null,
      'sender_role': globalRole.value,
      '_sending': true,
    };

    setState(() {
      _messages.add(tempMsg);
      _lastCount = _messages.length;
    });
    _scrollToBottom();

    try {
      final response = await ApiService.post(
        '/classes/${widget.classId}/messages',
        {'message': text},
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final saved = json.decode(response.body);
        // Cập nhật tên & avatar từ server nếu chưa có
        if (_myName.isEmpty) _myName = saved['sender_name'] ?? '';
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == tempId);
          if (idx != -1) _messages[idx] = saved;
          _lastCount = _messages.length;
          _isSending = false;
        });
        _scrollToBottom();
      } else if (response.statusCode == 403) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
          _lastCount = _messages.length;
          _isSending = false;
          _accessDenied = true;
        });
        _showError('Bạn không có quyền nhắn tin trong lớp này.');
      } else {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
          _lastCount = _messages.length;
          _isSending = false;
        });
        _showError('Không gửi được tin nhắn. Thử lại!');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'] == tempId);
          _lastCount = _messages.length;
          _isSending = false;
        });
        _showError('Lỗi kết nối mạng!');
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 120), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: RentsColors.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '';
    try {
      final dt = DateTime.parse(rawTime.toString()).toLocal();
      final now = DateTime.now();
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      if (isToday) return '$h:$m';
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      return '$d/$mo $h:$m';
    } catch (_) {
      return '';
    }
  }

  bool _shouldShowTimeDivider(int index) {
    if (index == 0) return true;
    try {
      final prev = DateTime.parse(_messages[index - 1]['created_at'].toString()).toLocal();
      final curr = DateTime.parse(_messages[index]['created_at'].toString()).toLocal();
      return curr.difference(prev).inMinutes >= 5;
    } catch (_) {
      return false;
    }
  }

  /// Nhãn vai trò tiếng Việt
  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':   return 'Admin';
      case 'staff':   return 'NV';
      case 'teacher': return 'GV';
      case 'student': return 'HV';
      default:        return '';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'admin':   return const Color(0xFFE74C3C);
      case 'staff':   return const Color(0xFF9B59B6);
      case 'teacher': return const Color(0xFF2ECC71);
      case 'student': return const Color(0xFF0047FF);
      default:        return RentsColors.grayDark;
    }
  }

  // ─── Widgets ────────────────────────────────────────────────────────────────

  Widget _buildTimeDivider(dynamic rawTime) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE0E7F0), thickness: 0.8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatTime(rawTime),
              style: const TextStyle(color: RentsColors.grayDark, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE0E7F0), thickness: 0.8)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String senderName) {
    final initials = senderName.isNotEmpty ? senderName[0].toUpperCase() : '?';
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: RentsColors.primaryBlue.withValues(alpha: 0.12),
        image: (avatarUrl != null && avatarUrl.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(ApiService.getImageUrl(avatarUrl)),
                fit: BoxFit.cover,
                onError: (e, _) {},
              )
            : null,
      ),
      child: (avatarUrl == null || avatarUrl.isEmpty)
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: RentsColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRoleBadge(String? role) {
    final label = _roleLabel(role);
    if (label.isEmpty) return const SizedBox.shrink();
    final color = _roleColor(role);
    return Container(
      margin: const EdgeInsets.only(left: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(dynamic message, bool isMe, bool showAvatar, bool showName) {
    final senderName = message['sender_name'] ?? 'Người dùng';
    final avatarUrl = message['sender_avatar'];
    final senderRole = message['sender_role'];
    final isSending = message['_sending'] == true;
    final timeStr = _formatTime(message['created_at']);

    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 60 : 16,
        right: isMe ? 16 : 60,
        top: showName ? 8 : 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (người khác)
          if (!isMe) ...[
            showAvatar
                ? _buildAvatar(avatarUrl, senderName)
                : const SizedBox(width: 34),
            const SizedBox(width: 8),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Tên + badge vai trò (chỉ khi thay đổi người gửi)
                if (showName) ...[
                  if (isMe)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildRoleBadge(senderRole),
                        const SizedBox(width: 4),
                        Text(
                          'Bạn',
                          style: const TextStyle(
                            fontSize: 11,
                            color: RentsColors.grayDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Text(
                          senderName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: RentsColors.grayDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildRoleBadge(senderRole),
                      ],
                    ),
                  const SizedBox(height: 4),
                ],

                // Bubble
                Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Spinner gửi (bên trái bubble của mình)
                    if (isSending && isMe)
                      const Padding(
                        padding: EdgeInsets.only(right: 6, bottom: 4),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5, color: RentsColors.grayMedium),
                        ),
                      ),

                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? RentsColors.primaryBlue : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 18),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          message['message'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : RentsColors.black,
                            fontSize: 15,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Thời gian gửi
                if (!isSending)
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 2, right: 2),
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        color: RentsColors.grayMedium,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: RentsColors.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, color: RentsColors.primaryBlue, size: 40),
          ),
          const SizedBox(height: 18),
          const Text(
            'Chưa có tin nhắn nào',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: RentsColors.black),
          ),
          const SizedBox(height: 6),
          const Text(
            'Hãy bắt đầu cuộc trò chuyện với lớp!',
            style: TextStyle(fontSize: 13, color: RentsColors.grayDark),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: RentsColors.accentRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: RentsColors.accentRed, size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'Không có quyền truy cập',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: RentsColors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Chỉ giảng viên, học viên của lớp và quản trị viên mới có thể xem tin nhắn.',
              style: TextStyle(fontSize: 13, color: RentsColors.grayDark, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: RentsColors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: RentsColors.primaryBlue.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.groups_rounded, color: RentsColors.primaryBlue, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.className,
                    style: const TextStyle(
                      color: RentsColors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Tin nhắn nhóm lớp',
                    style: TextStyle(color: RentsColors.grayDark, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!_accessDenied)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: RentsColors.primaryBlue),
              tooltip: 'Tải lại',
              onPressed: () => _fetchMessages(initial: true),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Danh sách tin nhắn ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: RentsColors.primaryBlue))
                : _accessDenied
                    ? _buildAccessDenied()
                    : _messages.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final senderId = int.tryParse(msg['sender_id'].toString()) ?? -1;
                              final isMe = senderId == _myUserId;

                              // Hiện tên khi thay đổi người gửi
                              final prevSenderId = index > 0
                                  ? int.tryParse(_messages[index - 1]['sender_id'].toString())
                                  : null;
                              final showName = prevSenderId != senderId;

                              // Hiện avatar cho tin nhắn cuối cùng của nhóm
                              final nextSenderId = index < _messages.length - 1
                                  ? int.tryParse(_messages[index + 1]['sender_id'].toString())
                                  : null;
                              final showAvatar = !isMe && nextSenderId != senderId;

                              return Column(
                                children: [
                                  if (_shouldShowTimeDivider(index))
                                    _buildTimeDivider(msg['created_at']),
                                  _buildMessageBubble(msg, isMe, showAvatar, showName),
                                ],
                              );
                            },
                          ),
          ),

          // ── Input bar (ẩn nếu không có quyền) ────────────────────────────
          if (!_accessDenied)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, -3)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // TextField
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 130),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          focusNode: _focusNode,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 15, color: RentsColors.black),
                          decoration: const InputDecoration(
                            hintText: 'Nhập tin nhắn...',
                            hintStyle: TextStyle(color: RentsColors.grayDark, fontSize: 15),
                            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút gửi
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _msgCtrl,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty;
                        return GestureDetector(
                          onTap: (_isSending || !hasText) ? null : _sendMessage,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 44,
                            height: 44,
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              color: hasText ? RentsColors.primaryBlue : const Color(0xFFCDD6E0),
                              shape: BoxShape.circle,
                            ),
                            child: _isSending
                                ? const Padding(
                                    padding: EdgeInsets.all(13),
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
