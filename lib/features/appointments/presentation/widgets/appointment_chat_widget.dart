import 'package:flutter/material.dart';
import 'dart:async';
import '../../../../models/appointment.dart';
import '../../../../models/appointment_message.dart';
import '../../../../services/appointment_service.dart';
import '../../../../services/auth_service.dart';

class AppointmentChatWidget extends StatefulWidget {
  final Appointment appointment;
  final VoidCallback? onMessageSent;

  const AppointmentChatWidget({
    super.key,
    required this.appointment,
    this.onMessageSent,
  });

  @override
  State<AppointmentChatWidget> createState() => _AppointmentChatWidgetState();
}

class _AppointmentChatWidgetState extends State<AppointmentChatWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<AppointmentMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  StreamSubscription<List<AppointmentMessage>>? _sub;
  String? _currentUserId;
  bool _canMessage = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = AuthService.instance.currentUser?.id;
    _initializeChat();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      _canMessage = await AppointmentService.instance.canMessageAppointment(
        widget.appointment.id,
      );

      final messages = await AppointmentService.instance.getAppointmentMessages(
        widget.appointment.id,
      );

      if (!mounted) return;
      setState(() {
        _messages = List.of(messages)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _loading = false;
      });
      _scrollToBottom();

      // listen
      _sub = AppointmentService.instance
          .streamAppointmentMessages(widget.appointment.id)
          .listen(
            (messages) {
              if (!mounted) return;
              final sorted = List.of(messages)
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
              setState(() => _messages = sorted);
              _scrollToBottom();
            },
            onError: (err) {
              if (!mounted) return;
              setState(() => _error = err.toString());
            },
          );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent; // bottom
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending || !_canMessage) return;

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await AppointmentService.instance.sendAppointmentMessage(
        widget.appointment.id,
        text,
      );
      _messageController.clear();
      widget.onMessageSent?.call();
      // updates come from stream
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _sending = false);
    }
  }

  Widget _buildMessage(AppointmentMessage message) {
    final isCurrentUser = message.senderId == _currentUserId;
    final isStaff = message.isFromStaff;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: isStaff
                  ? Colors.blue.withOpacity(0.2)
                  : Colors.grey[300],
              child: Icon(
                isStaff ? Icons.medical_services : Icons.person,
                size: 16,
                color: isStaff ? Colors.blue : Colors.grey[700],
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).colorScheme.primary
                    : isStaff
                    ? Colors.blue.withOpacity(0.08)
                    : Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isCurrentUser
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: isCurrentUser
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser) ...[
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isStaff
                            ? Colors.blue
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isCurrentUser
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isCurrentUser
                          ? Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.7)
                          : Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrentUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.2),
              child: Icon(
                Icons.person,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (d == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.month}/${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Appointment Chat',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                if (_messages.isNotEmpty)
                  Text(
                    '${_messages.length} message${_messages.length != 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // body
          Flexible(
            child: Builder(
              builder: (context) {
                if (_loading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (_error != null) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (!_canMessage) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You cannot send messages for this appointment.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // messages + input
                return Column(
                  children: [
                    // messages
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: _messages.isEmpty
                            ? const Center(
                                child: Text(
                                  'No messages yet. Start the conversation!',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                reverse: false,
                                itemCount: _messages.length,
                                itemBuilder: (context, index) {
                                  // newest at bottom, list sorted ascending by time
                                  return _buildMessage(_messages[index]);
                                },
                              ),
                      ),
                    ),
                    const Divider(height: 1),
                    // input
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Type your message...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceVariant,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: 3,
                              minLines: 1,
                              enabled: !_sending,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _sending ? null : _sendMessage,
                            icon: _sending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
