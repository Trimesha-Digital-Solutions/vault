import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/api/api_config.dart';

class ChatSocketService {
  io.Socket? _socket;

  void connect() {
    _socket ??= io.io(
      ApiConfig.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(5)
          .build(),
    );
    _socket!.connect();
  }

  void joinTeam(String teamId) => _socket?.emit('join_team', {'team_id': teamId});
  void leaveTeam(String teamId) => _socket?.emit('leave_team', {'team_id': teamId});

  void onMessage(void Function(dynamic) handler) {
    _socket?.on('message_new', handler);
  }

  void onReadReceipt(void Function(dynamic) handler) {
    _socket?.on('message_read', handler);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
