// ============================================================
// Fichier: admin_user_detail_screen.dart
// Description: Détail utilisateur admin (profil, rôle, actions)
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
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/admin/admin_feedback.dart';
import '../../widgets/admin/empty_state.dart';

/// Écran de détail d'un utilisateur (vue admin)
class AdminUserDetailScreen extends ConsumerStatefulWidget {
  final String userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  UserModel? _user;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final user = await adminRepo.getUser(widget.userId);
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _changeRole(String newRole) async {
    if (_user == null) return;

    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final updatedUser = await adminRepo.updateUserRole(_user!.id, newRole);
      setState(() => _user = updatedUser);

      if (mounted) {
        context.showInfo('Rôle changé en ${UserRole.fromString(newRole).displayName}');
      }
    } catch (e) {
      if (mounted) {
        context.showError('Erreur: $e');
      }
    }
  }

  Future<void> _toggleActive() async {
    if (_user == null) return;

    final activate = !_user!.isActive;
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final updatedUser = await adminRepo.toggleUserActive(_user!.id, activate);
      setState(() => _user = updatedUser);

      if (mounted) {
        if (activate) {
          context.showSuccess('Utilisateur activé');
        } else {
          context.showWarning('Utilisateur désactivé');
        }
      }
    } catch (e) {
      if (mounted) {
        context.showError('Erreur: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;

    if (currentUser == null || !currentUser.isAdmin) {
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: NeonColors.textPrimary),
          onPressed: () => context.go('/admin/users'),
        ),
        title: const Text(
          'Détail utilisateur',
          style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const NeonLoadingSpinner.center()
          : _error != null
              ? AdminErrorState(error: _error!, onRetry: _loadUser)
              : _user == null
                  ? const Center(child: Text('Utilisateur introuvable', style: TextStyle(color: NeonColors.textMuted)))
                  : RefreshIndicator(
                      onRefresh: _loadUser,
                      color: NeonColors.primary,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildProfileHeader(),
                          const SizedBox(height: 24),
                          _buildInfoSection(),
                          const SizedBox(height: 24),
                          _buildRoleSection(currentUser),
                          const SizedBox(height: 24),
                          _buildActionsSection(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildProfileHeader() {
    final roleColor = Color(int.parse(_user!.role.color.replaceFirst('#', '0xFF')));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [roleColor.withValues(alpha: 0.15), NeonColors.primary.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: roleColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          AvatarDisplay(avatarType: _user!.avatarType, size: 80),
          const SizedBox(height: 16),
          Text(
            _user!.username.isNotEmpty ? _user!.username : 'Sans nom',
            style: const TextStyle(color: NeonColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: roleColor),
            ),
            child: Text(
              _user!.role.displayName,
              style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
            ),
          ),
          if (!_user!.isActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: NeonColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('DÉSACTIVÉ', style: TextStyle(color: NeonColors.error, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return _Section(
      title: 'Informations',
      children: [
        _InfoRow(icon: Icons.phone, label: 'Téléphone', value: _user!.phone ?? 'Non renseigné'),
        _InfoRow(icon: Icons.email, label: 'Email', value: _user!.email ?? 'Non renseigné'),
        _InfoRow(icon: Icons.account_balance_wallet, label: 'Solde', value: '${_user!.balance.toStringAsFixed(2)} FCFA'),
        _InfoRow(icon: Icons.monetization_on, label: 'Jetons', value: _user!.tokenBalance.toString()),
        _InfoRow(icon: Icons.login, label: 'Connexions', value: '${_user!.loginCount}'),
        _InfoRow(
          icon: Icons.calendar_today,
          label: 'Dernière connexion',
          value: _user!.lastLoginAt != null
              ? '${_user!.lastLoginAt!.day}/${_user!.lastLoginAt!.month}/${_user!.lastLoginAt!.year}'
              : 'Jamais',
        ),
        _InfoRow(
          icon: Icons.verified_user,
          label: 'KYC',
          value: _user!.hasVerifiedKyc ? 'Vérifié' : 'Non vérifié',
        ),
      ],
    );
  }

  Widget _buildRoleSection(UserModel currentUser) {
    return _Section(
      title: 'Gestion du rôle',
      children: [
        ...UserRole.values.map((role) {
          final isSelected = _user!.role == role;
          final roleColor = Color(int.parse(role.color.replaceFirst('#', '0xFF')));
          final canAssign = currentUser.isSuperAdmin || 
              (currentUser.isAdmin && role != UserRole.superAdmin);

          return ListTile(
            leading: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? roleColor : NeonColors.border,
            ),
            title: Text(role.displayName, style: TextStyle(color: roleColor, fontWeight: FontWeight.w600)),
            trailing: isSelected
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Actuel', style: TextStyle(color: roleColor, fontSize: 11)),
                  )
                : null,
            enabled: canAssign && !isSelected,
            onTap: canAssign && !isSelected
                ? () => _confirmRoleChange(role)
                : null,
          );
        }),
      ],
    );
  }

  Widget _buildActionsSection() {
    return _Section(
      title: 'Actions',
      children: [
        ListTile(
          leading: Icon(
            _user!.isActive ? Icons.block : Icons.check_circle,
            color: _user!.isActive ? NeonColors.warning : NeonColors.primary,
          ),
          title: Text(
            _user!.isActive ? 'Désactiver le compte' : 'Activer le compte',
            style: TextStyle(
              color: _user!.isActive ? NeonColors.warning : NeonColors.primary,
            ),
          ),
          onTap: _toggleActive,
        ),
      ],
    );
  }

  void _confirmRoleChange(UserRole newRole) {
    final roleColor = Color(int.parse(newRole.color.replaceFirst('#', '0xFF')));

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NeonColors.card,
        title: const Text('Changer le rôle', style: TextStyle(color: NeonColors.textPrimary)),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(color: NeonColors.textSecondary, fontSize: 15),
            children: [
              const TextSpan(text: 'Attribuer le rôle '),
              TextSpan(text: newRole.displayName, style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)),
              const TextSpan(text: ' à '),
              TextSpan(text: _user!.username, style: const TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold)),
              const TextSpan(text: ' ?'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: roleColor),
            onPressed: () {
              Navigator.pop(dialogContext);
              _changeRole(newRole.value);
            },
            child: Text('Confirmer', style: TextStyle(color: roleColor == NeonColors.background ? NeonColors.background : NeonColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

// --- Widgets helpers ---

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: NeonColors.primary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
          const Spacer(),
          Flexible(
            child: Text(value, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
