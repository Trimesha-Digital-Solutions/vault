import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_provider.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import 'chat_input_bar.dart';
import 'message_bubble.dart';

/// Team chat UI (messages + input). Use inside a tab or wrap in [Scaffold] for full screen.
class TeamChatPanel extends ConsumerStatefulWidget {
  final String teamId;

  const TeamChatPanel({super.key, required this.teamId});

  @override
  ConsumerState<TeamChatPanel> createState() => _TeamChatPanelState();
}

class _TeamChatPanelState extends ConsumerState<TeamChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  ChatMessageModel? _replyingTo;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(chatControllerProvider(widget.teamId));
    final myId = ref.watch(currentUserIdProvider).valueOrNull;

    ref.listen(chatControllerProvider(widget.teamId), (prev, next) {
      next.whenData((_) => _scrollToBottom());
    });

    return Column(
      children: [
        Expanded(
          child: chatAsync.when(
            data: (messages) {
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet.\nSay hello to your team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final isMine =
                      myId != null && message.senderId == myId;
                  return GestureDetector(
                    onLongPress: () =>
                        setState(() => _replyingTo = message),
                    child: MessageBubble(message: message, isMine: isMine),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Failed to load chat: $e')),
          ),
        ),
        ChatInputBar(
          controller: _controller,
          replyingTo: _replyingTo,
          onClearReply: () => setState(() => _replyingTo = null),
          onSend: () async {
            final value = _controller.text.trim();
            if (value.isEmpty) return;
            await ref
                .read(chatControllerProvider(widget.teamId).notifier)
                .sendMessage(value, replyToId: _replyingTo?.id);
            _controller.clear();
            setState(() => _replyingTo = null);
            _scrollToBottom();
          },
        ),
      ],
    );
  }
}
