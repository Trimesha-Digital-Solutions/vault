import 'package:flutter/material.dart';
import '../models/chat_models.dart';

class ReplyPreview extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback onClear;
  const ReplyPreview({super.key, required this.message, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Replying to ${message.senderName}: ${message.content}')),
          IconButton(onPressed: onClear, icon: const Icon(Icons.close, size: 16)),
        ],
      ),
    );
  }
}
