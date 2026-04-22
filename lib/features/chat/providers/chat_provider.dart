import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_provider.dart';
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';

final chatApiServiceProvider = Provider((ref) => ChatApiService(ref.read(apiServiceProvider)));
final chatSocketServiceProvider = Provider((ref) => ChatSocketService());

class ChatController extends StateNotifier<AsyncValue<List<ChatMessageModel>>> {
  final Ref _ref;
  final String teamId;

  ChatController(this._ref, this.teamId) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final socket = _ref.read(chatSocketServiceProvider);
    socket.connect();
    socket.joinTeam(teamId);
    socket.onMessage((payload) {
      final current = state.valueOrNull ?? [];
      final incoming = ChatMessageModel.fromJson(Map<String, dynamic>.from(payload));
      if (current.any((m) => m.id == incoming.id)) return;
      state = AsyncValue.data([...current, incoming]);
    });
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final list = await _ref.read(chatApiServiceProvider).getMessages(teamId);
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendMessage(String content, {String? replyToId}) async {
    final sent = await _ref
        .read(chatApiServiceProvider)
        .sendMessage(teamId, content: content, replyToId: replyToId);
    final current = state.valueOrNull ?? [];
    if (!current.any((m) => m.id == sent.id)) {
      state = AsyncValue.data([...current, sent]);
    }
  }
}

final chatControllerProvider = StateNotifierProvider.autoDispose
    .family<ChatController, AsyncValue<List<ChatMessageModel>>, String>((ref, teamId) {
  ref.onDispose(() => ref.read(chatSocketServiceProvider).dispose());
  return ChatController(ref, teamId);
});
