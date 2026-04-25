import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../auth/auth_provider.dart';
import '../chat/screens/chat_thread_screen.dart';
import '../chat/widgets/team_chat_panel.dart';
import 'models/document_models.dart';
import 'models/team_models.dart';
import 'providers/team_provider.dart';
import 'shared_vault_screen.dart';

/// Full workspace for one team (members, chat, vaults, documents).
class TeamDetailScreen extends ConsumerStatefulWidget {
  final TeamModel team;

  const TeamDetailScreen({super.key, required this.team});

  @override
  ConsumerState<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends ConsumerState<TeamDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedTeamIdProvider.notifier).state = widget.team.id;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.watch(themeProvider.notifier);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final team = widget.team;
    final fabBottomPadding = MediaQuery.of(context).padding.bottom + 108;

    ref.listen(teamControllerProvider, (previous, next) {
      if (next is AsyncError) {
        _showError(next.error.toString());
      }
    });

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      appBar: AppBar(
        title: Text(team.name),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: 'Theme',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => themeNotifier.toggleTheme(),
          ),
          IconButton(
            tooltip: 'Team chat',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatThreadScreen(
                    teamId: team.id,
                    teamName: team.name,
                  ),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Copy team code',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: team.code));
              _showSuccess('Team code copied');
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
              child: Tooltip(
                message: 'Tap to copy invite code',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: team.code));
                    _showSuccess('Copied invite code');
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Code: ${team.code} • ${team.role} • ${team.memberCount} members',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorColor: AppColors.purple,
            labelColor: AppColors.purple,
            unselectedLabelColor: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.6),
            tabs: const [
              Tab(text: 'Members'),
              Tab(text: 'Chat'),
              Tab(text: 'Vaults'),
              Tab(text: 'Docs'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMembersTab(isDark, team),
                TeamChatPanel(teamId: team.id),
                _buildSharedVaultsTab(isDark, team),
                _buildDocumentsTab(isDark, team),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 1
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: fabBottomPadding),
              child: FloatingActionButton.extended(
                heroTag: 'team_detail_fab_${team.id}_${_tabController.index}',
                onPressed: () {
                  if (_tabController.index == 0) {
                    _showInviteDialog(context, team);
                  } else if (_tabController.index == 2) {
                    _showCreateVaultDialog(context, team);
                  } else {
                    _pickAndUploadDocument(team.id);
                  }
                },
                backgroundColor: AppColors.purple,
                icon: Icon(
                  _tabController.index == 0 ? Icons.person_add : Icons.add,
                  color: Colors.white,
                ),
                label: Text(
                  _tabController.index == 0
                      ? 'Invite'
                      : (_tabController.index == 2 ? 'New Vault' : 'Upload'),
                  style: const TextStyle(color: Colors.white),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
    );
  }

  Widget _buildMembersTab(bool isDark, TeamModel team) {
    final membersAsync = ref.watch(teamMembersProvider(team.id));

    return membersAsync.when(
      data: (members) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.purple, AppColors.purpleDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.purple.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('${members.length}', 'Members'),
                  _buildDivider(),
                  _buildStatItem(
                    '${members.where((m) => m.role == TeamRole.organiser).length}',
                    'Organisers',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Team Members',
              style: GoogleFonts.syne(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            if (team.role == TeamRole.organiser) ...[
              const SizedBox(height: 6),
              Text(
                'As organiser, tap someone’s role chip to change Organiser / Member.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...members.map((m) => _buildMemberTile(m, isDark, team)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading members: $e')),
    );
  }

  Widget _buildDocumentsTab(bool isDark, TeamModel team) {
    final docsAsync = ref.watch(teamDocumentsProvider(team.id));
    final membersAsync = ref.watch(teamMembersProvider(team.id));
    final myId = ref.watch(currentUserIdProvider).valueOrNull;

    return docsAsync.when(
      data: (docs) {
        return membersAsync.when(
          data: (members) {
            if (docs.isEmpty) {
              return Center(
                child: Text(
                  'No documents yet.\nUse Upload to share a file.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final accessLabel = _documentAccessLabel(doc, members.length);
                final canManage = team.role == TeamRole.organiser ||
                    (myId != null && doc.uploadedBy == myId);
                return ListTile(
                  tileColor: isDark
                      ? AppColors.darkBgSecondary
                      : AppColors.lightBgSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  title: Text(doc.name),
                  subtitle: Text(
                    '${doc.uploadedByName} • $accessLabel\n${doc.originalFilename} • ${(doc.fileSize / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    child: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      if (value == 'download') {
                        try {
                          await ref.read(teamServiceProvider).downloadDocument(
                                team.id,
                                doc.id,
                                doc.originalFilename,
                              );
                          if (context.mounted) {
                            _showSuccess('Opened file');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            _showError('Download failed: $e');
                          }
                        }
                      } else if (value == 'access' && canManage) {
                        final updated = await showDialog<List<String>?>(
                          context: context,
                          builder: (ctx) => DocumentAccessPickerDialog(
                            members: members,
                            initialAllowedIds: doc.allowedMemberIds,
                          ),
                        );
                        if (!context.mounted || updated == null) return;
                        try {
                          await ref
                              .read(teamServiceProvider)
                              .updateDocumentAccess(
                                team.id,
                                doc.id,
                                updated,
                              );
                          ref.invalidate(teamDocumentsProvider(team.id));
                          _showSuccess('Access updated');
                        } catch (e) {
                          _showError('Update failed: $e');
                        }
                      } else if (value == 'delete' && canManage) {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete document?'),
                            content: Text(
                              'Remove "${doc.name}" for everyone who has access?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok != true || !context.mounted) return;
                        try {
                          await ref
                              .read(teamServiceProvider)
                              .deleteDocument(team.id, doc.id);
                          ref.invalidate(teamDocumentsProvider(team.id));
                          _showSuccess('Document deleted');
                        } catch (e) {
                          _showError('Delete failed: $e');
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'download',
                        child: Text('Open / download'),
                      ),
                      if (canManage)
                        const PopupMenuItem(
                          value: 'access',
                          child: Text('Who can access'),
                        ),
                      if (canManage)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error loading members: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading documents: $e')),
    );
  }

  String _documentAccessLabel(TeamDocumentModel doc, int teamSize) {
    if (doc.allowedMemberIds.isEmpty) {
      return 'All $teamSize members';
    }
    final n = doc.allowedMemberIds.length;
    return '$n member${n == 1 ? '' : 's'}';
  }

  Widget _buildSharedVaultsTab(bool isDark, TeamModel team) {
    final vaultsAsync = ref.watch(teamVaultsProvider(team.id));

    return vaultsAsync.when(
      data: (vaults) {
        if (vaults.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_off_outlined,
                    size: 60, color: Colors.grey.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  'No shared vaults yet',
                  style: TextStyle(color: Colors.grey.withValues(alpha: 0.8)),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vaults.length,
          itemBuilder: (context, index) {
            return _buildVaultTile(vaults[index], isDark, team);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildVaultTile(
      SharedVaultModel vault, bool isDark, TeamModel team) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SharedVaultScreen(vault: vault, teamId: team.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  const Icon(Icons.folder_shared, color: AppColors.purple),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vault.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                  Text(
                    '${vault.memberIds.length} members • ${vault.passwordCount} passwords',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: isDark ? Colors.white54 : Colors.black45,
              onPressed: () =>
                  _showEditVaultDialog(context, team, vault),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(
      TeamMemberModel member, bool isDark, TeamModel team) {
    final canManageRoles = team.role == TeamRole.organiser;
    final roleChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: member.role == TeamRole.organiser
            ? AppColors.purple.withValues(alpha: 0.2)
            : (isDark
                ? Colors.white10
                : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        member.role,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: member.role == TeamRole.organiser
              ? AppColors.purple
              : (isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSecondary : AppColors.lightBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.purple,
            child: Text(
              member.name.isNotEmpty
                  ? member.name.substring(0, 1).toUpperCase()
                  : 'U',
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  member.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (canManageRoles)
            PopupMenuButton<String>(
              tooltip: 'Change role',
              onSelected: (value) async {
                try {
                  await ref.read(teamServiceProvider).updateMemberRole(
                        team.id,
                        member.id,
                        value,
                      );
                  ref.invalidate(teamMembersProvider(team.id));
                  ref.invalidate(myTeamsProvider);
                  if (!context.mounted) return;
                  _showSuccess('${member.name} is now $value');
                } catch (e) {
                  if (!context.mounted) return;
                  _showError('$e');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: TeamRole.organiser,
                  child: Text(TeamRole.organiser),
                ),
                PopupMenuItem(
                  value: TeamRole.member,
                  child: Text(TeamRole.member),
                ),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  roleChip,
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: member.role == TeamRole.organiser
                        ? AppColors.purple
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  ),
                ],
              ),
            )
          else
            roleChip,
        ],
      ),
    );
  }

  Future<void> _pickAndUploadDocument(String teamId) async {
    final result = await FilePicker.platform.pickFiles(withData: kIsWeb);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;

    if (kIsWeb) {
      if (file.bytes == null) {
        _showError(
          'Could not read file (web). Try a smaller file or another browser.',
        );
        return;
      }
    } else if (file.path == null && file.bytes == null) {
      return;
    }

    List<String>? allowedMemberIds;
    try {
      final members = await ref.read(teamMembersProvider(teamId).future);
      if (!mounted) return;
      allowedMemberIds = await showDialog<List<String>?>(
        context: context,
        builder: (ctx) => DocumentAccessPickerDialog(
          members: members,
          initialAllowedIds: const [],
        ),
      );
    } catch (e) {
      if (mounted) _showError('Could not load members: $e');
      return;
    }
    if (!mounted || allowedMemberIds == null) return;

    try {
      await ref.read(teamServiceProvider).uploadDocument(
            teamId,
            name: file.name,
            fileName: file.name,
            filePath: kIsWeb ? null : file.path,
            fileBytes:
                kIsWeb ? file.bytes : (file.path == null ? file.bytes : null),
            allowedMemberIds: allowedMemberIds,
          );
      if (!mounted) return;
      ref.invalidate(teamDocumentsProvider(teamId));
      _showSuccess('Document uploaded');
    } catch (e) {
      if (!mounted) return;
      _showError('Upload failed: $e');
    }
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.syne(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }

  void _showInviteDialog(BuildContext context, TeamModel team) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Member'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email Address'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (emailController.text.isNotEmpty) {
                ref.read(teamControllerProvider.notifier).inviteMember(
                      team.id,
                      emailController.text,
                    );
                Navigator.pop(context);
                _showSuccess('Invitation sent!');
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }

  void _showCreateVaultDialog(BuildContext context, TeamModel team) {
    showDialog(
      context: context,
      builder: (context) => CreateSharedVaultDialog(team: team),
    );
  }

  void _showEditVaultDialog(
      BuildContext context, TeamModel team, SharedVaultModel vault) {
    showDialog(
      context: context,
      builder: (context) =>
          CreateSharedVaultDialog(team: team, existingVault: vault),
    );
  }
}

enum DocAccessScope { everyone, selected }

class DocumentAccessPickerDialog extends StatefulWidget {
  final List<TeamMemberModel> members;
  final List<String> initialAllowedIds;

  const DocumentAccessPickerDialog({
    super.key,
    required this.members,
    required this.initialAllowedIds,
  });

  @override
  State<DocumentAccessPickerDialog> createState() =>
      _DocumentAccessPickerDialogState();
}

class _DocumentAccessPickerDialogState extends State<DocumentAccessPickerDialog> {
  late DocAccessScope _scope;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialAllowedIds.isEmpty) {
      _scope = DocAccessScope.everyone;
    } else {
      _scope = DocAccessScope.selected;
      _selectedIds.addAll(widget.initialAllowedIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Who can access this document?'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Share with',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All team members'),
                    selected: _scope == DocAccessScope.everyone,
                    onSelected: (_) => setState(
                      () => _scope = DocAccessScope.everyone,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Only selected'),
                    selected: _scope == DocAccessScope.selected,
                    onSelected: (_) => setState(
                      () => _scope = DocAccessScope.selected,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_scope == DocAccessScope.selected)
                ...widget.members.map((m) => CheckboxListTile(
                      dense: true,
                      value: _selectedIds.contains(m.id),
                      title: Text(m.name),
                      subtitle: Text(
                        m.email,
                        style: const TextStyle(fontSize: 11),
                      ),
                      onChanged: (on) {
                        setState(() {
                          if (on == true) {
                            _selectedIds.add(m.id);
                          } else {
                            _selectedIds.remove(m.id);
                          }
                        });
                      },
                    )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_scope == DocAccessScope.everyone) {
              Navigator.pop(context, <String>[]);
            } else {
              if (_selectedIds.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Select at least one team member.'),
                  ),
                );
                return;
              }
              Navigator.pop(context, _selectedIds.toList());
            }
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class CreateSharedVaultDialog extends ConsumerStatefulWidget {
  final TeamModel team;
  final SharedVaultModel? existingVault;

  const CreateSharedVaultDialog({
    super.key,
    required this.team,
    this.existingVault,
  });

  @override
  ConsumerState<CreateSharedVaultDialog> createState() =>
      _CreateSharedVaultDialogState();
}

class _CreateSharedVaultDialogState
    extends ConsumerState<CreateSharedVaultDialog> {
  late TextEditingController _nameController;
  List<String> _selectedMemberIds = [];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingVault?.name ?? '');
    _selectedMemberIds = List.from(widget.existingVault?.memberIds ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final membersAsync = ref.watch(teamMembersProvider(team.id));

    return AlertDialog(
      title: Text(widget.existingVault == null
          ? 'New Shared Vault'
          : 'Edit Shared Vault'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Vault Name'),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select Members:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: membersAsync.when(
                data: (members) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isSelected =
                          _selectedMemberIds.contains(member.id);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(member.name),
                        subtitle: Text(member.email),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedMemberIds.add(member.id);
                            } else {
                              _selectedMemberIds.remove(member.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_nameController.text.isEmpty) return;
            final navigator = Navigator.of(context);

            if (widget.existingVault == null) {
              await ref.read(teamServiceProvider).createSharedVault(
                    team.id,
                    _nameController.text,
                    _selectedMemberIds,
                  );
              if (!mounted) return;
              ref.invalidate(teamVaultsProvider(team.id));
              navigator.pop();
            } else {
              ref.read(teamControllerProvider.notifier).updateVault(
                    team.id,
                    widget.existingVault!.id,
                    _nameController.text,
                    _selectedMemberIds,
                  );
              navigator.pop();
            }
          },
          child: Text(widget.existingVault == null ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}
