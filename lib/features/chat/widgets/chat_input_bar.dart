import 'package:flutter/material.dart';
import '../models/chat_models.dart';
import 'reply_preview.dart';

class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final ChatMessageModel? replyingTo;
  final VoidCallback onSend;
  final VoidCallback onClearReply;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.replyingTo,
    required this.onSend,
    required this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (replyingTo != null)
              ReplyPreview(message: replyingTo!, onClear: onClearReply),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onSend,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
