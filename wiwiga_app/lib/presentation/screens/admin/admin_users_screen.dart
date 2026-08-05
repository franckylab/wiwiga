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
        backgroundColor: const Color(0xFF0A0A1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text('Accès non autorisé', style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/home'), child: const Text('Retour')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
        title: Text(
          'Utilisateurs ($_total)',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (user.isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.person_add, color: Color(0xFF00FF88)),
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
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par nom, email, phone...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF00FF88)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00FF88), width: 1),
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
                  color: const Color(0xFF1A1A2E),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _roleFilter != null
                          ? const Color(0xFF00FF88).withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: _roleFilter != null ? const Color(0xFF00FF88) : Colors.white54,
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: null, child: Text('Tous les rôles', style: TextStyle(color: Colors.white))),
                    ...UserRole.values.map((role) {
                      final color = Color(int.parse(role.color.replaceFirst('#', '0xFF')));
                      return PopupMenuItem(
                        value: role.value,
                        child: Row(
                          children: [
                            Icon(Icons.circle, color: color, size: 12),
                            const SizedBox(width: 8),
                            Text(role.displayName, style: const TextStyle(color: Colors.white)),
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
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.white54)),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _loadUsers, child: const Text('Réessayer')),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline, color: Colors.white24, size: 64),
                                SizedBox(height: 12),
                                Text('Aucun utilisateur trouvé', style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            color: const Color(0xFF00FF88),
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
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Créer un utilisateur', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Pseudonyme *',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    labelStyle: TextStyle(color: Colors.white54),
                    hintText: '+237 6XX XXX XXX',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(height: 16),
                // Sélection rôle
                DropdownButtonFormField<String>(
                  initialValue: selectedRole,
                  dropdownColor: const Color(0xFF1A1A2E),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Rôle',
                    labelStyle: TextStyle(color: Colors.white54),
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
              child: const Text('Annuler', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
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
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Utilisateur créé avec succès'),
                        backgroundColor: Color(0xFF00FF88),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Créer', style: TextStyle(color: Color(0xFF0A0A1A))),
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
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                  ),
                ],
              ),
            ),

            // Status
            Column(
              children: [
                Icon(
                  user.isActive ? Icons.check_circle : Icons.cancel,
                  color: user.isActive ? const Color(0xFF00FF88) : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  user.isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    color: user.isActive ? const Color(0xFF00FF88) : Colors.redAccent,
                    fontSize: 10,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
