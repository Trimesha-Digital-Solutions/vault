import '../../../core/api/api_config.dart';
import '../../../core/api/api_service.dart';
import '../models/chat_models.dart';

class ChatApiService {
  final ApiService _apiService;

  ChatApiService(this._apiService);

  Future<List<ChatMessageModel>> getMessages(String teamId) async {
    final response =
        await _apiService.dio.get('${ApiConfig.baseUrl}/api/teams/$teamId/messages');
    return (response.data as List).map((e) => ChatMessageModel.fromJson(e)).toList();
  }

  Future<ChatMessageModel> sendMessage(
    String teamId, {
    required String content,
    String? replyToId,
  }) async {
    final response = await _apiService.dio.post(
      '${ApiConfig.baseUrl}/api/teams/$teamId/messages',
      data: {
        'content': content,
        'reply_to_id': replyToId,
        'message_type': 'text',
      },
    );
    return ChatMessageModel.fromJson(response.data);
  }

  Future<void> markRead(String teamId, String messageId) async {
    await _apiService.dio.post(
      '${ApiConfig.baseUrl}/api/teams/$teamId/messages/read',
      data: {'message_id': messageId},
    );
  }
}
