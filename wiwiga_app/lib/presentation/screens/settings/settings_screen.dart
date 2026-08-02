import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/app_providers.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/auth/success_animation.dart';

// === Providers ===

final soundEnabledProvider = StateProvider<bool>((ref) => true);
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);
final notificationsEnabledProvider = StateProvider<bool>((ref) => true);
final responsibleGamingLimitProvider = StateProvider<int?>((ref) => 5000); // En jetons
final otpRequiredProvider = StateProvider<bool>((ref) => false);

// === Écran ===

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    _loadOtpSetting();
  }

  void _loadOtpSetting() async {
    final settings = await ref.read(authProvider.notifier).getAuthSettings();
    if (mounted) {
      ref.read(otpRequiredProvider.notifier).state =
          settings['otp_required_on_login'] as bool? ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      trailing: const GlowBadge(text: 'OK', color: NeonColors.success),
                      onTap: () => _showSnackbar(context, 'KYC - Bientôt disponible'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('JEU', [
                    _buildToggleTile(
                      icon: Icons.volume_up,
                      title: 'Sons',
                      provider: soundEnabledProvider,
                      color: NeonColors.warning,
                    ),
                    _buildToggleTile(
                      icon: Icons.vibration,
                      title: 'Vibrations',
                      provider: vibrationEnabledProvider,
                      color: NeonColors.warning,
                    ),
                    _buildToggleTile(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      provider: notificationsEnabledProvider,
                      color: NeonColors.warning,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildSection('JEU RESPONSABLE', [
                    _buildResponsibleGamingTile(),
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
                    _buildOtpToggle(context),
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
                    onPressed: () => _performLogout(context),
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

  void _performLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        title: const Text('Déconnexion', style: TextStyle(color: NeonColors.textPrimary)),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?', style: TextStyle(color: NeonColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                _showLogoutAnimation(context);
              }
            },
            child: const Text('Déconnexion', style: TextStyle(color: NeonColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showLogoutAnimation(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      pageBuilder: (ctx, _, __) => const Scaffold(
        backgroundColor: Color(0xFF0A0A1A),
        body: Center(
          child: SuccessAnimation(
            message: 'Déconnecté',
            subtitle: 'À bientôt sur WIWIGA !',
            duration: Duration(milliseconds: 1200),
          ),
        ),
      ),
      transitionDuration: Duration.zero,
    );
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/auth');
      }
    });
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NeonColors.info.withValues(alpha: 0.2), NeonColors.background],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: NeonColors.info, size: 28),
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
            style: const TextStyle(
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

  Widget _buildToggleTile({
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
            color: enabled ? color.withValues(alpha: 0.3) : NeonColors.border,
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

  Widget _buildResponsibleGamingTile() {
    final limit = ref.watch(responsibleGamingLimitProvider);
    return _SettingsTile(
      icon: Icons.monetization_on,
      title: 'Limite de mise / jour',
      subtitle: limit != null ? '$limit jetons' : 'Illimité',
      color: NeonColors.error,
      onTap: () => _showLimitDialog(),
    );
  }

  Widget _buildOtpToggle(BuildContext context) {
    final otpEnabled = ref.watch(otpRequiredProvider);
    return _SettingsTile(
      icon: Icons.security,
      title: 'Vérification OTP à la connexion',
      subtitle: otpEnabled ? 'Activée — Code requis' : 'Désactivée',
      color: otpEnabled ? NeonColors.success : NeonColors.textSecondary,
      trailing: GestureDetector(
        onTap: () => _toggleOtp(context, !otpEnabled),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: otpEnabled ? NeonColors.success.withValues(alpha: 0.3) : NeonColors.border,
            border: Border.all(color: otpEnabled ? NeonColors.success : NeonColors.textSecondary),
          ),
          padding: const EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: otpEnabled ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: otpEnabled ? NeonColors.success : NeonColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      onTap: () => _toggleOtp(context, !otpEnabled),
    );
  }

  void _toggleOtp(BuildContext context, bool newValue) {
    ref.read(authProvider.notifier).updateOtpRequired(enabled: newValue).then((success) {
      if (success) {
        ref.read(otpRequiredProvider.notifier).state = newValue;
        _showSnackbar(context, newValue ? 'OTP activé' : 'OTP désactivé');
      } else {
        _showSnackbar(context, 'Erreur de mise à jour');
      }
    });
  }

  void _showLimitDialog() {
    final controller = TextEditingController(
      text: ref.read(responsibleGamingLimitProvider)?.toString() ?? '',
    );
    // Simple dialog via snackbar for now
    ref.read(responsibleGamingLimitProvider.notifier).state = 100000;
  }

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: NeonColors.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatTokens(int amount) {
    return amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ',);
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
          border: Border(bottom: BorderSide(color: NeonColors.border.withValues(alpha: 0.3))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.15),
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
                    style: const TextStyle(
                      color: NeonColors.textPrimary,
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: NeonColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing! else
              const Icon(Icons.chevron_right, color: NeonColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
