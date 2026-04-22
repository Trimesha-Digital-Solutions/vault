import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/auth_provider.dart';
import '../models/team_models.dart';
import '../models/document_models.dart';
import '../services/team_service.dart';
import '../../vault/models/password_model.dart';

final teamServiceProvider = Provider((ref) {
  return TeamService(ref.read(apiServiceProvider));
});

// Teams List Provider
final myTeamsProvider =
    FutureProvider.autoDispose<List<TeamModel>>((ref) async {
  return await ref.read(teamServiceProvider).getMyTeams();
});

// Selected Team ID Provider
final selectedTeamIdProvider = StateProvider<String?>((ref) => null);

// Selected Team Provider (derived)
final selectedTeamProvider = Provider.autoDispose<TeamModel?>((ref) {
  final teams = ref.watch(myTeamsProvider).asData?.value ?? [];
  final selectedId = ref.watch(selectedTeamIdProvider);
  if (selectedId == null) {
    // Default to first team if exists
    if (teams.isNotEmpty) return teams.first;
    return null;
  }
  return teams.firstWhere(
    (t) => t.id == selectedId,
    orElse: () =>
        teams.isNotEmpty ? teams.first : throw Exception("No teams found"),
  );
});

// Members Provider
final teamMembersProvider = FutureProvider.autoDispose
    .family<List<TeamMemberModel>, String>((ref, teamId) async {
  return await ref.read(teamServiceProvider).getTeamMembers(teamId);
});

// Vaults Provider
final teamVaultsProvider = FutureProvider.autoDispose
    .family<List<SharedVaultModel>, String>((ref, teamId) async {
  return await ref.read(teamServiceProvider).getTeamVaults(teamId);
});

final teamDocumentsProvider = FutureProvider.autoDispose
    .family<List<TeamDocumentModel>, String>((ref, teamId) async {
  return await ref.read(teamServiceProvider).getDocuments(teamId);
});

// Shared Vault Passwords Provider
final sharedVaultPasswordsProvider = FutureProvider.autoDispose
    .family<List<PasswordModel>, ({String teamId, String vaultId})>(
        (ref, args) async {
  final rawList = await ref
      .read(teamServiceProvider)
      .getSharedPasswords(args.teamId, args.vaultId);
  return rawList
      .map((e) => PasswordModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class TeamController extends StateNotifier<AsyncValue<void>> {
  final TeamService _teamService;
  final Ref _ref;

  TeamController(this._teamService, this._ref)
      : super(const AsyncValue.data(null));

  Future<void> createTeam(String name) async {
    state = const AsyncValue.loading();
    try {
      final team = await _teamService.createTeam(name);
      _ref.read(selectedTeamIdProvider.notifier).state = team.id;
      _ref.invalidate(myTeamsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> joinTeam(String code) async {
    state = const AsyncValue.loading();
    try {
      final team = await _teamService.joinTeam(code);
      _ref.read(selectedTeamIdProvider.notifier).state = team.id;
      _ref.invalidate(myTeamsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createVault(String teamId, String name) async {
    state = const AsyncValue.loading();
    try {
      await _teamService.createSharedVault(teamId, name);
      _ref.invalidate(teamVaultsProvider(teamId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateVault(String teamId, String vaultId, String name,
      List<String> memberIds) async {
    state = const AsyncValue.loading();
    try {
      await _teamService.updateSharedVault(teamId, vaultId, name, memberIds);
      _ref.invalidate(teamVaultsProvider(teamId));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> inviteMember(String teamId, String email) async {
    state = const AsyncValue.loading();
    try {
      await _teamService.inviteMember(teamId, email);
      // Members list won't change immediately until they accept/it's processed,
      // but if we did add them as pending, we'd reload.
      // Current backend sends email details.
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateMemberRole(
      String teamId, String userId, String role) async {
    state = const AsyncValue.loading();
    try {
      await _teamService.updateMemberRole(teamId, userId, role);
      _ref.invalidate(teamMembersProvider(teamId));
      _ref.invalidate(myTeamsProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final teamControllerProvider =
    StateNotifierProvider<TeamController, AsyncValue<void>>((ref) {
  return TeamController(ref.read(teamServiceProvider), ref);
});
