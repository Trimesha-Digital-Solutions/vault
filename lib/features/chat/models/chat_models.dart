class ChatMessageModel {
  final String id;
  final String teamId;
  final String senderId;
  final String senderName;
  final String content;
  final String? replyToId;
  final String? replyToPreview;
  final String? replyToSender;
  final List<String> readBy;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.replyToId,
    this.replyToPreview,
    this.replyToSender,
    required this.readBy,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'],
      teamId: json['team_id'],
      senderId: json['sender_id'],
      senderName: json['sender_name'],
      content: json['content'],
      replyToId: json['reply_to_id'],
      replyToPreview: json['reply_to_preview'],
      replyToSender: json['reply_to_sender'],
      readBy: List<String>.from(json['read_by'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
