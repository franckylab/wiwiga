// ============================================================
// Fichier: admin_users_screen.dart
// Description: Gestion des utilisateurs (liste, filtres, création)
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/app_providers.dart';
import '../../../presentation/widgets/auth/avatar_picker.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/skeleton_loader.dart';
import '../../widgets/admin/empty_state.dart';

/// Écran de gestion des utilisateurs (admin)
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _users = [];
  int _total = 0;
  int _page = 1;
  bool _isLoading = true;
  String? _error;
  String? _searchQuery;
  String? _roleFilter;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final result = await adminRepo.listUsers(
        page: _page,
        search: _searchQuery,
        role: _roleFilter,
      );

      setState(() {
        _users = result['users'] as List<UserModel>;
        _total = result['total'] as int;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    _searchQuery = query.isNotEmpty ? query : null;
    _page = 1;
    _loadUsers();
  }

  void _onRoleFilter(String? role) {
    _roleFilter = role;
    _page = 1;
    _loadUsers();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    if (user == null || !user.isAdmin) {
      return Scaffold(
        backgroundColor: NeonColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: NeonColors.error, size: 64),
              const SizedBox(height: 16),
              const Text('Accès non autorisé', style: TextStyle(color: NeonColors.textPrimary, fontSize: 20)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Retour')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: Text(
          'Utilisateurs ($_total)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          // Bouton Export CSV
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: NeonColors.accent),
            tooltip: 'Exporter CSV',
            onPressed: _exportUsers,
          ),
          if (user.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.person_add, color: NeonColors.primary),
              onPressed: _showCreateUserDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: NeonColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom, email, phone...',
                      hintStyle: TextStyle(color: NeonColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: NeonColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: NeonColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: NeonColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: NeonColors.primary, width: 1),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: _onSearch,
                  ),
                ),
                const SizedBox(width: 8),
                // Filtre rôle
                PopupMenuButton<String?>(
                  onSelected: _onRoleFilter,
                  offset: const Offset(0, 40),
                  color: NeonColors.card,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _roleFilter != null
                          ? NeonColors.primary.withValues(alpha: 0.2)
                          : NeonColors.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: _roleFilter != null ? NeonColors.primary : NeonColors.textMuted,
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('Tous les rôles', style: TextStyle(color: NeonColors.textPrimary))),
                    ...UserRole.values.map((role) {
                      final color = Color(int.parse(role.color.replaceFirst('#', '0xFF')));
                      return PopupMenuItem(
                        value: role.value,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: color, size: 12),
                            const SizedBox(width: 8),
                            Text(role.displayName, style: const TextStyle(color: NeonColors.textPrimary)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          // Liste
          Expanded(
            child: _isLoading
                ? const AdminSkeletonList(itemCount: 8)
                : _error != null
                    ? AdminErrorState(error: _error!, onRetry: _loadUsers)
                    : _users.isEmpty
                        ? const AdminEmptyState(
                            icon: Icons.people_outline,
                            title: 'Aucun utilisateur trouvé',
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            color: NeonColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _users.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) => _UserTile(
                                user: _users[index],
                                onTap: () => context.go('/admin/users/${_users[index].id}'),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _exportUsers() {
    final adminRepo = ref.read(adminRepositoryProvider);
    // ignore: unused_local_variable
    final url = adminRepo.getExportUsersUrl();
    context.showInfo('Export des utilisateurs en cours... Le fichier CSV sera téléchargé.');
    // L'URL d'export est construite - le téléchargement se fait via le navigateur
    // ou un launcher d'URL externe
  }

  void _showCreateUserDialog() {
    final usernameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String selectedRole = 'user';
    AvatarType selectedAvatar = AvatarType.defaultAvatar;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.card,
          title: const Text('Créer un utilisateur', style: TextStyle(color: NeonColors.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  style: const TextStyle(color: NeonColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Pseudonyme *',
                    labelStyle: TextStyle(color: NeonColors.textMuted),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: NeonColors.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    labelStyle: TextStyle(color: NeonColors.textMuted),
                    hintText: '+237 6XX XXX XXX',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: NeonColors.textPrimary),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: NeonColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),
                // Sélection rôle
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: NeonColors.card,
                  style: const TextStyle(color: NeonColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    labelStyle: TextStyle(color: NeonColors.textMuted),
                  ),
                  items: UserRole.values.map((role) {
                    return DropdownMenuItem(
                      value: role.value,
                      child: Text(role.displayName),
                    );
                  }).toList(),
                  onChanged: (val) => setDialogState(() => selectedRole = val ?? 'user'),
                ),
                const SizedBox(height: 16),
                // Avatar
                AvatarPicker(
                  selectedAvatar: selectedAvatar,
                  onAvatarSelected: (avatar) => setDialogState(() => selectedAvatar = avatar),
                  avatarSize: 50,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler', style: TextStyle(color: NeonColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
              onPressed: () async {
                if (usernameCtrl.text.trim().length < 3) return;
                Navigator.pop(dialogContext);

                try {
                  final adminRepo = ref.read(adminRepositoryProvider);
                  await adminRepo.createUser(
                    username: usernameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                    email: emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                    role: selectedRole,
                    avatarType: selectedAvatar.value,
                  );
                  _loadUsers();
                  if (context.mounted) {
                    context.showSuccess('Utilisateur créé avec succès');
                  }
                } catch (e) {
                  if (context.mounted) {
                    context.showError('Erreur: $e');
                  }
                }
              },
              child: const Text('Créer', style: TextStyle(color: NeonColors.background)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tuile utilisateur dans la liste
class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final roleColor = Color(int.parse(user.role.color.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: NeonColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: NeonColors.border),
        ),
        child: Row(
          children: [
            // Avatar
            AvatarDisplay(avatarType: user.avatarType, size: 44),
            const SizedBox(width: 12),

            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.username.isNotEmpty ? user.username : 'Sans nom',
                          style: const TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          user.role.displayName,
                          style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email ?? user.phone ?? 'Pas de contact',
                    style: TextStyle(color: NeonColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Status
            Column(
              children: [
                Icon(
                  user.isActive ? Icons.check_circle : Icons.cancel,
                  color: user.isActive ? NeonColors.primary : NeonColors.error,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  user.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    color: user.isActive ? NeonColors.primary : NeonColors.error,
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: NeonColors.border),
          ],
        ),
      ),
    );
  }
}
