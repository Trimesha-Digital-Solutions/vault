import 'package:flutter/material.dart';
import '../models/chat_models.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;
  const MessageBubble({super.key, required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? Colors.deepPurple : Colors.grey.shade300;
    final fg = isMine ? Colors.white : Colors.black87;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(message.senderName,
                  style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 11)),
            if (message.replyToPreview != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  border: Border(
                    left: BorderSide(
                      color: fg.withValues(alpha: 0.5),
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.replyToSender != null)
                      Text(
                        message.replyToSender!,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      message.replyToPreview!,
                      style: TextStyle(color: fg, fontSize: 11),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            Text(message.content, style: TextStyle(color: fg)),
            Text(
              '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
