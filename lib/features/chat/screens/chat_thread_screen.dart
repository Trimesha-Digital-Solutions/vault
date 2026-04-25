import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/team_chat_panel.dart';

class ChatThreadScreen extends ConsumerWidget {
  final String teamId;
  final String teamName;
  const ChatThreadScreen({super.key, required this.teamId, required this.teamName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('$teamName chat')),
      body: TeamChatPanel(teamId: teamId),
    );
  }
}
