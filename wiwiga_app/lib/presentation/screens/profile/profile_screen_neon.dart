// ============================================================
// Fichier: profile_screen_neon.dart
// Description: Écran profil joueur avec design system néon
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/preferences_provider.dart';
import '../../../data/providers/user_profile_provider.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Écran ===

class ProfileScreenNeon extends ConsumerWidget {
  const ProfileScreenNeon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Charger les stats profil au premier build
    Future.microtask(() {
      if (!ref.read(userProfileProvider).isLoading && ref.read(userProfileProvider).profile == null) {
        ref.read(userProfileProvider.notifier).loadProfile();
      }
    });

    return Scaffold(
      backgroundColor: NeonColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(userProfileProvider.notifier).loadProfile();
          },
          color: NeonColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _ProfileHeader(user: user)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _ProfileStats()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              SliverToBoxAdapter(child: _SettingsSections()),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

// === Header ===

class _ProfileHeader extends ConsumerWidget {
  final dynamic user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.profile;
    final rankLabel = profile?.rankLabel ?? 'Bronze';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NeonColors.primary.withValues(alpha: 0.1),
            NeonColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: NeonColors.primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: NeonColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 47,
              backgroundColor: NeonColors.surface,
              child: Text(
                user?.username?.substring(0, 1).toUpperCase() ?? 'U',
                style: AppTypography.heading1.copyWith(
                  color: NeonColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Username
          Text(
            user?.username ?? 'Utilisateur',
            style: AppTypography.heading2.copyWith(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          // Phone
          Text(
            user?.phone ?? '+237 6XX XXX XXX',
            style: AppTypography.bodyMedium.copyWith(
              color: NeonColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  NeonColors.rankGold,
                  NeonColors.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: NeonColors.rankGold.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  rankLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// === Stats ===

class _ProfileStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final profile = profileState.profile;
    final gamesPlayed = profile?.gamesPlayed ?? 0;
    final wins = profile?.wins ?? 0;
    final xp = profile?.xpPoints ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _StatCard(label: 'Parties', value: '$gamesPlayed', icon: Icons.sports_esports)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Victoires', value: '$wins', icon: Icons.emoji_events)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'XP', value: '$xp', icon: Icons.star)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeonColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: NeonColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.heading3.copyWith(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: NeonColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// === Settings Sections ===

class _SettingsSections extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SettingsSections> createState() => _SettingsSectionsState();
}

class _SettingsSectionsState extends ConsumerState<_SettingsSections> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(preferencesProvider.notifier).loadPreferences();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Paramètres du compte
          Text(
            'PARAMÈTRES DU COMPTE',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Modifier le profil',
                onTap: () => context.push('/settings'),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Changer le mot de passe',
                onTap: () => _showChangePasswordDialog(context),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.phone_android,
                title: 'Changer le numéro',
                onTap: () => _showChangePhoneDialog(context),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.security,
                title: 'Vérification KYC',
                trailing: const GlowBadge(
                  text: 'Vérifié',
                  color: NeonColors.success,
                  fontSize: 10,
                ),
                onTap: () => _showKycDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Préférences
          Text(
            'PRÉFÉRENCES',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                trailing: Switch(
                  value: prefs.notificationsEnabled,
                  onChanged: (value) => ref.read(preferencesProvider.notifier).updateBool('notifications_enabled', value),
                  activeThumbColor: NeonColors.primary,
                ),
                onTap: () => ref.read(preferencesProvider.notifier).updateBool('notifications_enabled', !prefs.notificationsEnabled),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.volume_up_outlined,
                title: 'Sons',
                trailing: Switch(
                  value: prefs.soundEnabled,
                  onChanged: (value) => ref.read(preferencesProvider.notifier).updateBool('sound_enabled', value),
                  activeThumbColor: NeonColors.primary,
                ),
                onTap: () => ref.read(preferencesProvider.notifier).updateBool('sound_enabled', !prefs.soundEnabled),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.animation,
                title: 'Animations',
                trailing: Switch(
                  value: prefs.vibrationEnabled,
                  onChanged: (value) => ref.read(preferencesProvider.notifier).updateBool('vibration_enabled', value),
                  activeThumbColor: NeonColors.primary,
                ),
                onTap: () => ref.read(preferencesProvider.notifier).updateBool('vibration_enabled', !prefs.vibrationEnabled),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Jeu responsable
          Text(
            'JEU RESPONSABLE',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.monetization_on_outlined,
                title: 'Limites de dépôt',
                onTap: () => _showDepositLimitsDialog(context),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.schedule,
                title: 'Limites de temps',
                onTap: () => _showTimeLimitsDialog(context),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.block,
                title: 'Auto-exclusion',
                onTap: () => _showSelfExclusionDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Support
          Text(
            'SUPPORT',
            style: AppTypography.heading3,
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                title: 'Centre d\'aide',
                onTap: () => _showHelpDialog(context),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.chat_outlined,
                title: 'Contacter le support',
                onTap: () => _showSupportDialog(context),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.description_outlined,
                title: 'Conditions d\'utilisation',
                onTap: () => context.push('/legal/terms'),
              ),
              _SettingsDivider(),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Politique de confidentialité',
                onTap: () => context.push('/legal/privacy'),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Déconnexion
          NeonButton(
            text: 'DÉCONNEXION',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.go('/auth');
              }
            },
            variant: NeonButtonVariant.danger,
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Centre d\'aide', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Bienvenue dans l\'aide WIWIGA !\n\n'
          '• Pour jouer, créez ou rejoignez une partie\n'
          '• Gérez vos jetons dans le Wallet\n'
          '• Invitez des amis et jouez ensemble\n'
          '• Consultez les règles de chaque jeu\n\n'
          'Contact: support@wiwiga.cm',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Support', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Besoin d\'aide ?', style: TextStyle(color: NeonColors.textSecondary)),
          SizedBox(height: 16),
          Row(children: [
            Icon(Icons.email, color: NeonColors.primary, size: 20),
            SizedBox(width: 8),
            Text('support@wiwiga.cm', style: TextStyle(color: NeonColors.textPrimary)),
          ],),
          SizedBox(height: 12),
          Row(children: [
            Icon(Icons.phone, color: NeonColors.primary, size: 20),
            SizedBox(width: 8),
            Text('+237 6XX XXX XXX', style: TextStyle(color: NeonColors.textPrimary)),
          ],),
        ],),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showDepositLimitsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limites de dépôt', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Fixez-vous des limites de dépôt pour contrôler vos dépenses.\n\n'
          '• Limite journalière\n'
          '• Limite hebdomadaire\n'
          '• Limite mensuelle\n\n'
          'Ces limites vous aident à jouer de manière responsable.',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showTimeLimitsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Limites de temps', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Gérez votre temps de jeu pour rester maître de vos sessions.\n\n'
          '• Limite de session\n'
          '• Rappels périodiques\n'
          '• Historique de jeu\n\n'
          'Le jeu doit rester un plaisir, pas une contrainte.',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showSelfExclusionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Auto-exclusion', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Si vous sentez que le jeu devient un problème, vous pouvez vous auto-exclure.\n\n'
          '• Exclusion temporaire (24h, 7j, 30j)\n'
          '• Exclusion définitive\n'
          '• Support et ressources\n\n'
          'Votre bien-être est notre priorité.',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Changer le mot de passe', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Pour changer votre mot de passe, veuillez contacter le support.\n\n'
          'Email: support@wiwiga.cm\n'
          'Téléphone: +237 6XX XXX XXX',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showChangePhoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Changer le numéro', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Pour changer votre numéro de téléphone, veuillez contacter le support.\n\n'
          'Email: support@wiwiga.cm\n'
          'Téléphone: +237 6XX XXX XXX',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }

  void _showKycDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Vérification KYC', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
        content: const Text(
          'Votre compte est vérifié KYC.\n\n'
          'La vérification KYC (Know Your Customer) est un processus de vérification d\'identité obligatoire pour garantir la sécurité de tous les utilisateurs.\n\n'
          'Avantages:\n'
          '• Retraits illimités\n'
          '• Accès à toutes les fonctionnalités\n'
          '• Sécurité renforcée',
          style: TextStyle(color: NeonColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
        ],
      ),
    );
  }
}

// === Settings Widgets ===

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return NeonCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: NeonColors.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: NeonColors.textPrimary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
            ] else ...[
              const Icon(
                Icons.chevron_right,
                color: NeonColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Divider(color: NeonColors.border, height: 1),
    );
  }
}
