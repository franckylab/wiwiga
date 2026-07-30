import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../widgets/neon/neon_widgets.dart';

// === Providers ===

final soundEnabledProvider = StateProvider<bool>((ref) => true);
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final responsibleGamingLimitProvider = StateProvider<int?>((ref) => 50000);

// === Écran ===

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  _buildSection('COMPTE', [
                    _SettingsTile(
                      icon: Icons.person,
                      title: 'Profil',
                      subtitle: 'Modifier mes informations',
                      color: NeonColors.primary,
                      onTap: () => _showSnackbar(context, 'Profil - Bientôt disponible'),
                    ),
                    _SettingsTile(
                      icon: Icons.phone,
                      title: 'Numéro Mobile Money',
                      subtitle: '+237 6XX XXX XXX',
                      color: NeonColors.success,
                      onTap: () => _showSnackbar(context, 'Modification numéro - Bientôt disponible'),
                    ),
                    _SettingsTile(
                      icon: Icons.verified_user,
                      title: 'Vérification KYC',
                      subtitle: 'Statut: Vérifié',
                      color: NeonColors.info,
                      trailing: GlowBadge(text: 'OK', color: NeonColors.success),
                      onTap: () => _showSnackbar(context, 'KYC - Bientôt disponible'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('JEU', [
                    _buildToggleTile(
                      ref,
                      icon: Icons.volume_up,
                      title: 'Sons',
                      provider: soundEnabledProvider,
                      color: NeonColors.warning,
                    ),
                    _buildToggleTile(
                      ref,
                      icon: Icons.vibration,
                      title: 'Vibrations',
                      provider: vibrationEnabledProvider,
                      color: NeonColors.warning,
                    ),
                    _buildToggleTile(
                      ref,
                      icon: Icons.notifications,
                      title: 'Notifications',
                      provider: notificationsEnabledProvider,
                      color: NeonColors.warning,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('JEU RESPONSABLE', [
                    _buildResponsibleGamingTile(ref),
                    _SettingsTile(
                      icon: Icons.timer,
                      title: 'Limite de temps',
                      subtitle: 'Pas de limite',
                      color: NeonColors.error,
                      onTap: () => _showSnackbar(context, 'Limite de temps - Bientôt disponible'),
                    ),
                    _SettingsTile(
                      icon: Icons.block,
                      title: 'Auto-exclusion',
                      subtitle: 'Désactivé',
                      color: NeonColors.error,
                      onTap: () => _showSnackbar(context, 'Auto-exclusion - Bientôt disponible'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('SÉCURITÉ', [
                    _SettingsTile(
                      icon: Icons.lock,
                      title: 'Changer le code PIN',
                      subtitle: 'Dernière modification: il y a 30 jours',
                      color: NeonColors.info,
                      onTap: () => _showSnackbar(context, 'Changement PIN - Bientôt disponible'),
                    ),
                    _SettingsTile(
                      icon: Icons.fingerprint,
                      title: 'Biométrie',
                      subtitle: 'Désactivée',
                      color: NeonColors.info,
                      onTap: () => _showSnackbar(context, 'Biométrie - Bientôt disponible'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('À PROPOS', [
                    _SettingsTile(
                      icon: Icons.description,
                      title: 'Conditions générales',
                      color: NeonColors.textSecondary,
                      onTap: () => _showSnackbar(context, 'CGU - Bientôt disponible'),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip,
                      title: 'Politique de confidentialité',
                      color: NeonColors.textSecondary,
                      onTap: () => _showSnackbar(context, 'Politique - Bientôt disponible'),
                    ),
                    _SettingsTile(
                      icon: Icons.info,
                      title: 'Version',
                      subtitle: '1.0.0 (build 42)',
                      color: NeonColors.textSecondary,
                      onTap: () {},
                    ),
                  ]),
                  const SizedBox(height: 24),
                  // Logout
                  NeonButton(
                    text: 'Déconnexion',
                    onPressed: () => _showSnackbar(context, 'Déconnexion - Bientôt disponible'),
                    variant: NeonButtonVariant.danger,
                    icon: Icons.logout,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NeonColors.info.withOpacity(0.2), NeonColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.settings, color: NeonColors.info, size: 28),
          const SizedBox(width: 8),
          Text('PARAMÈTRES', style: AppTypography.heading3),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Text(
            title,
            style: TextStyle(
              color: NeonColors.textSecondary,
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ),
        NeonCard(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildToggleTile(
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required StateProvider<bool> provider,
    required Color color,
  }) {
    final enabled = ref.watch(provider);
    return _SettingsTile(
      icon: icon,
      title: title,
      color: color,
      trailing: GestureDetector(
        onTap: () => ref.read(provider.notifier).state = !enabled,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: enabled ? color.withOpacity(0.3) : NeonColors.border,
            border: Border.all(color: enabled ? color : NeonColors.textSecondary),
          ),
          padding: const EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: enabled ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? color : NeonColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      onTap: () => ref.read(provider.notifier).state = !enabled,
    );
  }

  Widget _buildResponsibleGamingTile(WidgetRef ref) {
    final limit = ref.watch(responsibleGamingLimitProvider);
    return _SettingsTile(
      icon: Icons.account_balance_wallet,
      title: 'Limite de mise / jour',
      subtitle: limit != null ? '${_formatFCFA(limit)} FCFA' : 'Illimité',
      color: NeonColors.error,
      onTap: () => _showLimitDialog(ref),
    );
  }

  void _showLimitDialog(WidgetRef ref) {
    final controller = TextEditingController(
      text: ref.read(responsibleGamingLimitProvider)?.toString() ?? '',
    );
    // Simple dialog via snackbar for now
    ref.read(responsibleGamingLimitProvider.notifier).state = 100000;
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: NeonColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatFCFA(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ');
  }
}

// === Settings Tile ===

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.color,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: NeonColors.border.withOpacity(0.3))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: NeonColors.textPrimary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: NeonColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing! else
              Icon(Icons.chevron_right, color: NeonColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
