class TeamDocumentModel {
  final String id;
  final String teamId;
  final String name;
  final String originalFilename;
  final int fileSize;
  final String mimeType;
  final String uploadedBy;
  final String uploadedByName;
  final List<String> allowedMemberIds;
  final DateTime createdAt;

  TeamDocumentModel({
    required this.id,
    required this.teamId,
    required this.name,
    required this.originalFilename,
    required this.fileSize,
    required this.mimeType,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.allowedMemberIds,
    required this.createdAt,
  });

  factory TeamDocumentModel.fromJson(Map<String, dynamic> json) {
    return TeamDocumentModel(
      id: json['id'],
      teamId: json['team_id'],
      name: json['name'],
      originalFilename: json['original_filename'],
      fileSize: json['file_size'],
      mimeType: json['mime_type'],
      uploadedBy: json['uploaded_by'],
      uploadedByName: json['uploaded_by_name'],
      allowedMemberIds: List<String>.from(json['allowed_member_ids'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
