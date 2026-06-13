import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
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
  // IDs tin nhắn đang ẩn cục bộ (chỉ trong phiên này)
  final Set<int> _hiddenMessageIds = {};

  File? _selectedFile;
  String? _selectedFileName;
  String? _selectedFileType;

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
        final bool hasNew = msgs.length > _lastCount;
        final int prevCount = _lastCount;
        
        setState(() {
          _messages = msgs;
          _lastCount = msgs.length;
          if (initial) _isLoading = false;
        });
        
        if (hasNew && !initial) {
          // Show notification for new messages from others
          for (int i = prevCount; i < msgs.length; i++) {
            final msg = msgs[i];
            if (msg['sender_id'] != _myUserId) {
              final name = msg['sender_name'] ?? 'Người dùng';
              final content = msg['message']?.toString().isNotEmpty == true 
                  ? msg['message'] 
                  : '[Đã gửi một tệp đính kèm]';
              _showSimpleNotification('$name: $content');
            }
          }
          _scrollToBottom();
        } else if (initial) {
          _scrollToBottom();
        }
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

  void _showSimpleNotification(String text) {
    if (!mounted) return;
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -50.0, end: 0.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: RentsColors.primaryBlue.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      entry?.remove();
    });
  }

  /// Ẩn tin nhắn cục bộ (chỉ trong phiên này)
  void _hideMessage(int msgId) {
    setState(() => _hiddenMessageIds.add(msgId));
  }

  /// Xóa tin nhắn (soft-delete trên server, chỉ trong 1 tiếng)
  Future<void> _deleteMessage(dynamic message) async {
    final msgId = message['id'];
    final sentAt = DateTime.tryParse(message['created_at']?.toString() ?? '')?.toLocal();
    if (sentAt == null) return;

    final diffMinutes = DateTime.now().difference(sentAt).inMinutes;
    if (diffMinutes > 60) {
      _showError('Chỉ có thể xóa tin nhắn trong vòng 1 tiếng sau khi gửi.');
      return;
    }

    // Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xóa tin nhắn', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Tin nhắn sẽ bị xóa với tất cả mọi người trong lớp. Bạn có chắc chắn?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: RentsColors.accentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      final response = await ApiService.delete('/classes/${widget.classId}/messages/$msgId');
      if (!mounted) return;
      if (response.statusCode == 200) {
        // Cập nhật tin nhắn trong danh sách
        setState(() {
          final idx = _messages.indexWhere((m) => m['id'] == msgId);
          if (idx != -1) _messages[idx] = {..._messages[idx], 'is_deleted': 1};
        });
      } else {
        final body = json.decode(response.body);
        _showError(body['message'] ?? 'Không thể xóa tin nhắn.');
      }
    } catch (e) {
      _showError('Lỗi kết nối mạng!');
    }
  }

  final List<String> _basicEmojis = ['❤️', '😆', '😮', '😢', '😡', '👍'];

  Future<void> _toggleReaction(dynamic message, String emoji) async {
    final msgId = message['id'];
    if (msgId == null || msgId < 0) return;

    // Optimistic UI updates
    List reactions = List.from(message['reactions'] ?? []);
    final existingIdx = reactions.indexWhere((r) => r['user_id'] == _myUserId);
    
    String? newReaction;
    if (existingIdx != -1) {
      if (reactions[existingIdx]['reaction'] == emoji) {
        reactions.removeAt(existingIdx); // remove
      } else {
        reactions[existingIdx] = {...reactions[existingIdx], 'reaction': emoji}; // update
        newReaction = emoji;
      }
    } else {
      reactions.add({'user_id': _myUserId, 'reaction': emoji, 'user_name': _myName});
      newReaction = emoji;
    }

    setState(() {
      final idx = _messages.indexWhere((m) => m['id'] == msgId);
      if (idx != -1) _messages[idx] = {..._messages[idx], 'reactions': reactions};
    });

    try {
      final response = await ApiService.post('/classes/${widget.classId}/messages/$msgId/react', {
        'reaction': newReaction,
      });
      if (response.statusCode != 200) {
        _showError('Không thể thả cảm xúc. Thử lại!');
        _fetchMessages(); // revert
      }
    } catch (_) {
      _showError('Lỗi kết nối!');
      _fetchMessages(); // revert
    }
  }

  /// Hiển thị bottom sheet tùy chọn khi nhấn giữ
  void _showMessageOptions(dynamic message, bool isMe) {
    final msgId = int.tryParse(message['id'].toString()) ?? -1;
    if (msgId < 0 || message['_sending'] == true) return;

    final isDeleted = message['is_deleted'] == 1 || message['is_deleted'] == true;
    if (isDeleted) return; // không có tùy chọn cho tin đã xóa

    // Kiểm tra còn trong 1 tiếng không
    final sentAt = DateTime.tryParse(message['created_at']?.toString() ?? '')?.toLocal();
    final canDelete = isMe && sentAt != null && DateTime.now().difference(sentAt).inMinutes <= 60;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(color: RentsColors.grayMedium, borderRadius: BorderRadius.circular(2)),
              ),
              // Hàng thả cảm xúc
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _basicEmojis.map((emoji) {
                    final reactions = message['reactions'] as List? ?? [];
                    final isReacted = reactions.any((r) => r['user_id'] == _myUserId && r['reaction'] == emoji);
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleReaction(message, emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isReacted ? RentsColors.primaryBlue.withValues(alpha: 0.15) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 28)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              // Preview tin nhắn
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: RentsColors.bgGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message['message']?.toString() ?? '',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: RentsColors.grayDark, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              // Nút Ẩn
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined, color: RentsColors.grayDark),
                title: const Text('Ẩn tin nhắn', style: TextStyle(fontWeight: FontWeight.w500)),
                subtitle: const Text('Chỉ ẩn với bạn trong phiên này'),
                onTap: () {
                  Navigator.pop(ctx);
                  _hideMessage(msgId);
                },
              ),
              if (message['file_url'] != null && message['file_url'].toString().isNotEmpty) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.download_rounded, color: RentsColors.primaryBlue),
                  title: const Text('Lưu tệp đính kèm', style: TextStyle(fontWeight: FontWeight.w500, color: RentsColors.primaryBlue)),
                  subtitle: Text(message['file_name'] ?? 'Tải tệp này xuống', style: const TextStyle(fontSize: 12, color: RentsColors.grayDark)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = Uri.parse(ApiService.getImageUrl(message['file_url']));
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      _showError('Không thể mở liên kết để tải xuống.');
                    }
                  },
                ),
              ],
              if (isMe) ...[  
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: canDelete ? RentsColors.accentRed : RentsColors.grayMedium,
                  ),
                  title: Text(
                    'Xóa tin nhắn',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: canDelete ? RentsColors.accentRed : RentsColors.grayMedium,
                    ),
                  ),
                  subtitle: Text(
                    canDelete
                        ? 'Xóa với tất cả mọi người trong lớp'
                        : 'Đã quá 1 tiếng, không thể xóa',
                    style: TextStyle(
                      color: canDelete ? RentsColors.grayDark : RentsColors.grayMedium,
                      fontSize: 12,
                    ),
                  ),
                  enabled: canDelete,
                  onTap: canDelete ? () {
                    Navigator.pop(ctx);
                    _deleteMessage(message);
                  } : null,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _selectedFile == null) return;
    if (_isSending) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    final fileToSend = _selectedFile;
    final fileName = _selectedFileName;
    final fileType = _selectedFileType;

    setState(() {
      _selectedFile = null;
      _selectedFileName = null;
      _selectedFileType = null;
    });

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
      'file_url': fileToSend?.path,
      'file_name': fileName,
      'file_type': fileType,
      'is_local_file': fileToSend != null,
      '_sending': true,
    };

    setState(() {
      _messages.add(tempMsg);
      _lastCount = _messages.length;
    });
    _scrollToBottom();

    try {
      var response;
      if (fileToSend != null) {
        response = await ApiService.postMultipart(
          '/classes/${widget.classId}/messages',
          {
            'message': text,
            'file_type': fileType ?? 'file',
          },
          filePath: fileToSend.path,
          fileField: 'file',
        );
      } else {
        response = await ApiService.post(
          '/classes/${widget.classId}/messages',
          {'message': text},
        );
      }

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
    final isDeleted = message['is_deleted'] == 1 || message['is_deleted'] == true;
    final senderName = message['sender_name'] ?? 'Người dùng';
    final avatarUrl = message['sender_avatar'];
    final senderRole = message['sender_role'];
    final isSending = message['_sending'] == true;
    final timeStr = _formatTime(message['created_at']);

    // Hiển thị tin nhắn đã xóa
    if (isDeleted) {
      return Padding(
        padding: EdgeInsets.only(
          left: isMe ? 60 : 16,
          right: isMe ? 16 : 60,
          top: 2, bottom: 2,
        ),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMe) const SizedBox(width: 42),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: RentsColors.grayLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.not_interested, size: 14, color: RentsColors.grayDark),
                  const SizedBox(width: 6),
                  const Text(
                    'Tin nhắn đã bị xóa',
                    style: TextStyle(color: RentsColors.grayDark, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message, isMe),
      child: Padding(
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
                  // Tên + badge vai trò
                  if (showName) ...[
                    if (isMe)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildRoleBadge(senderRole),
                          const SizedBox(width: 4),
                          const Text('Bạn', style: TextStyle(fontSize: 11, color: RentsColors.grayDark, fontWeight: FontWeight.w600)),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Text(senderName, style: const TextStyle(fontSize: 11, color: RentsColors.grayDark, fontWeight: FontWeight.w600)),
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
                      if (isSending && isMe)
                        const Padding(
                          padding: EdgeInsets.only(right: 6, bottom: 4),
                          child: SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: RentsColors.grayMedium),
                          ),
                        ),
                      Flexible(
                        child: Container(
                          padding: _isImageMessage(message) 
                              ? EdgeInsets.only(bottom: (message['message']?.toString() ?? '').isNotEmpty ? 10 : 0)
                              : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 18),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (message['file_url'] != null || message['file_name'] != null)
                                  _buildFileAttachment(message, isMe),
                                if ((message['message']?.toString() ?? '').isNotEmpty)
                                  Padding(
                                    padding: _isImageMessage(message)
                                        ? const EdgeInsets.symmetric(horizontal: 14)
                                        : EdgeInsets.zero,
                                    child: Text(
                                      message['message'] ?? '',
                                      style: TextStyle(
                                        color: isMe ? Colors.white : RentsColors.black,
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Reactions & Thời gian gửi
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isSending)
                        Padding(
                          padding: const EdgeInsets.only(left: 2, right: 2),
                          child: Text(timeStr, style: const TextStyle(fontSize: 10, color: RentsColors.grayMedium)),
                        ),
                      if (message['reactions'] != null && (message['reactions'] as List).isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildReactionsBadge(message['reactions']),
                      ],
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

  Widget _buildReactionsBadge(List reactions) {
    Map<String, int> counts = {};
    for (var r in reactions) {
      final emoji = r['reaction']?.toString() ?? '';
      if (emoji.isNotEmpty) counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final emojis = counts.keys.toList();
    final total = reactions.length;

    return GestureDetector(
      onTap: () => _showReactionsDetails(reactions),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: RentsColors.grayLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...emojis.map((e) => Text(e, style: const TextStyle(fontSize: 12))),
            if (total > 1) ...[
              const SizedBox(width: 2),
              Text(
                '$total',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: RentsColors.primaryBlue),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showReactionsDetails(List reactions) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: RentsColors.grayMedium, borderRadius: BorderRadius.circular(2))),
              const Text('Cảm xúc', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: reactions.map((r) => ListTile(
                      leading: Text(r['reaction'] ?? '', style: const TextStyle(fontSize: 24)),
                      title: Text(r['user_name'] ?? 'Người dùng', style: const TextStyle(fontWeight: FontWeight.w600)),
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showImageFullScreen(String url, bool isLocal) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: isLocal
                    ? Image.file(File(url), fit: BoxFit.contain)
                    : Image.network(ApiService.getImageUrl(url), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isImageMessage(dynamic message) {
    final fileUrl = message['file_url'];
    final fileType = message['file_type'] ?? 'file';
    if (fileUrl == null) return false;
    
    bool isImage = fileType == 'image';
    if (!isImage) {
      final ext = fileUrl.toString().toLowerCase();
      if (ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif') || ext.endsWith('.webp')) {
        isImage = true;
      }
    }
    return isImage;
  }

  Widget _buildFileAttachment(dynamic message, bool isMe) {
    final fileUrl = message['file_url'];
    final fileName = message['file_name'] ?? 'Tập tin đính kèm';
    final fileType = message['file_type'] ?? 'file';
    final isLocal = message['is_local_file'] == true;

    final isImage = _isImageMessage(message);

    if (isImage && fileUrl != null) {
      return GestureDetector(
        onTap: () => _showImageFullScreen(fileUrl, isLocal),
        child: Container(
          margin: EdgeInsets.only(bottom: (message['message']?.toString() ?? '').isNotEmpty ? 8 : 0),
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: isLocal ? FileImage(File(fileUrl)) : NetworkImage(ApiService.getImageUrl(fileUrl)) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
          child: AspectRatio(aspectRatio: 16/9, child: Container()),
        ),
      );
    }

    // Các file khác (pdf, doc, xls, ppt, ...)
    IconData iconData = Icons.insert_drive_file;
    Color iconColor = RentsColors.primaryBlue;
    if (fileType == 'pdf') { iconData = Icons.picture_as_pdf; iconColor = RentsColors.accentRed; }
    else if (fileType == 'word') { iconData = Icons.description; iconColor = const Color(0xFF2B579A); }
    else if (fileType == 'excel') { iconData = Icons.table_chart; iconColor = const Color(0xFF217346); }
    else if (fileType == 'ppt') { iconData = Icons.slideshow; iconColor = const Color(0xFFD24726); }

    return GestureDetector(
      onTap: () async {
        if (fileUrl != null) {
          final url = Uri.parse(ApiService.getImageUrl(fileUrl));
          if (await canLaunchUrl(url)) await launchUrl(url);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: EdgeInsets.only(bottom: (message['message']?.toString() ?? '').isNotEmpty ? 8 : 0),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withValues(alpha: 0.2) : RentsColors.bgGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isMe ? Colors.white.withValues(alpha: 0.3) : RentsColors.grayLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconData, color: isMe ? Colors.white : iconColor, size: 24),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                fileName,
                style: TextStyle(
                  color: isMe ? Colors.white : RentsColors.black,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
                              final msgId = int.tryParse(msg['id'].toString()) ?? -1;

                              // Bỏ qua tin nhắn đang ẩn cục bộ
                              if (_hiddenMessageIds.contains(msgId)) {
                                return const SizedBox.shrink();
                              }

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
                    // Cột input
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectedFile != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: RentsColors.bgLightBlue,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: RentsColors.primaryBlue.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedFileType == 'image' ? Icons.image : Icons.insert_drive_file,
                                    color: RentsColors.primaryBlue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedFileName ?? 'Tập tin đính kèm',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12, color: RentsColors.black, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedFile = null;
                                      _selectedFileName = null;
                                      _selectedFileType = null;
                                    }),
                                    child: const Icon(Icons.close, size: 18, color: RentsColors.grayDark),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 130),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F2F5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: RentsColors.grayDark, size: 22),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.only(left: 14, right: 8),
                                      onPressed: () async {
                                        try {
                                          FilePickerResult? result = await FilePicker.pickFiles(type: FileType.any);
                                          if (result != null && result.files.single.path != null) {
                                            final ext = result.files.single.extension?.toLowerCase() ?? '';
                                            final allowedFileExts = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'];
                                            if (allowedFileExts.contains(ext)) {
                                              setState(() {
                                                _selectedFile = File(result.files.single.path!);
                                                _selectedFileName = result.files.single.name;
                                                if (ext == 'pdf') _selectedFileType = 'pdf';
                                                else if (['doc', 'docx'].contains(ext)) _selectedFileType = 'word';
                                                else if (['xls', 'xlsx'].contains(ext)) _selectedFileType = 'excel';
                                                else if (['ppt', 'pptx'].contains(ext)) _selectedFileType = 'ppt';
                                                else _selectedFileType = 'file';
                                              });
                                            } else {
                                              _showError('Chỉ hỗ trợ file PDF, Word, Excel, PPT và TXT.');
                                            }
                                          }
                                        } catch (e) {
                                          _showError('Không thể chọn file: $e');
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.image_outlined, color: RentsColors.grayDark, size: 22),
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.only(left: 4, right: 8),
                                      onPressed: () async {
                                        try {
                                          final ImagePicker picker = ImagePicker();
                                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                                          if (image != null) {
                                            setState(() {
                                              _selectedFile = File(image.path);
                                              _selectedFileName = image.name;
                                              _selectedFileType = 'image';
                                            });
                                          }
                                        } catch (e) {
                                          _showError('Không thể chọn ảnh: $e');
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                Expanded(
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
                                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Nút gửi
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _msgCtrl,
                      builder: (context, value, child) {
                        final hasText = value.text.trim().isNotEmpty || _selectedFile != null;
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
