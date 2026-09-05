import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';
import '../../../data/providers/app_providers.dart';
import '../../../data/providers/biometric_provider.dart';
import '../../../data/providers/preferences_provider.dart';
import '../../../data/providers/responsible_gaming_provider.dart';
import '../../../data/providers/sessions_provider.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/auth/success_animation.dart';

// === Providers conservés pour compatibilité ===
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
    _loadData();
  }

  void _loadData() async {
    // Charger les préférences depuis le serveur
    await ref.read(preferencesProvider.notifier).loadPreferences();
    // Charger les sessions
    await ref.read(sessionsProvider.notifier).loadSessions();
    // Charger les limites de jeu responsable
    await ref.read(responsibleGamingProvider.notifier).loadLimits();
    // Charger OTP setting
    final settings = await ref.read(authProvider.notifier).getAuthSettings();
    if (mounted) {
      ref.read(otpRequiredProvider.notifier).state =
          settings['otp_required_on_login'] as bool? ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(preferencesProvider);

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
                  // COMPTE
                  _buildSection('COMPTE', [
                    _SettingsTile(
                      icon: Icons.phone,
                      title: 'Numéro Mobile Money',
                      subtitle: ref.watch(authProvider).user?.phone ?? 'Non défini',
                      color: NeonColors.success,
                      onTap: () => _showSnackbar(context, 'Modification numéro - Contactez le support'),
                    ),
                    // KYC masqué pour v1
                  ]),
                  const SizedBox(height: 16),

                  // PRÉFÉRENCES APP
                  _buildSection('PRÉFÉRENCES', [
                    _buildBoolToggleTile(
                      icon: Icons.volume_up,
                      title: 'Sons',
                      value: prefs.soundEnabled,
                      onChanged: (v) => ref.read(preferencesProvider.notifier).updateBool('sound_enabled', v),
                      color: NeonColors.warning,
                    ),
                    _buildBoolToggleTile(
                      icon: Icons.vibration,
                      title: 'Vibrations',
                      value: prefs.vibrationEnabled,
                      onChanged: (v) => ref.read(preferencesProvider.notifier).updateBool('vibration_enabled', v),
                      color: NeonColors.warning,
                    ),
                    _buildBoolToggleTile(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      value: prefs.notificationsEnabled,
                      onChanged: (v) => ref.read(preferencesProvider.notifier).updateBool('notifications_enabled', v),
                      color: NeonColors.warning,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // AFFICHAGE
                  _buildSection('AFFICHAGE', [
                    _buildSelectTile(
                      icon: Icons.language,
                      title: 'Langue',
                      value: prefs.language == 'fr' ? 'Français' : 'English',
                      options: const {'fr': 'Français', 'en': 'English'},
                      onSelect: (v) => ref.read(preferencesProvider.notifier).updateString('language', v),
                      color: NeonColors.info,
                    ),
                    _buildSelectTile(
                      icon: Icons.palette,
                      title: 'Thème',
                      value: _themeLabel(prefs.theme),
                      options: const {'neon': 'Néon', 'dark': 'Sombre', 'light': 'Clair'},
                      onSelect: (v) => ref.read(preferencesProvider.notifier).updateString('theme', v),
                      color: NeonColors.accent,
                    ),
                    _buildSelectTile(
                      icon: Icons.text_fields,
                      title: 'Taille du texte',
                      value: _fontSizeLabel(prefs.fontSize),
                      options: const {'small': 'Petit', 'medium': 'Moyen', 'large': 'Grand'},
                      onSelect: (v) => ref.read(preferencesProvider.notifier).updateString('font_size', v),
                      color: NeonColors.primary,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // JEU RESPONSABLE (hub dédié : limites, pause, exclusion)
                  _buildSection('JEU RESPONSABLE', [
                    _SettingsTile(
                      icon: Icons.monetization_on,
                      title: 'Limites de jeu',
                      subtitle: ref.watch(responsibleGamingProvider).dailyLossLimitLabel,
                      color: NeonColors.error,
                      onTap: () => context.push('/responsible-gaming/limits'),
                    ),
                    _SettingsTile(
                      icon: Icons.block,
                      title: 'Auto-exclusion',
                      subtitle: ref.watch(responsibleGamingProvider).selfExclusionLabel,
                      color: ref.watch(responsibleGamingProvider).isSelfExcluded
                          ? NeonColors.error
                          : NeonColors.textSecondary,
                      onTap: () => context.push('/responsible-gaming/limits'),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // SÉCURITÉ
                  _buildSection('SÉCURITÉ', [
                    _buildOtpToggle(context),
                    _SettingsTile(
                      icon: Icons.lock,
                      title: 'Changer le mot de passe',
                      subtitle: 'Modifier votre mot de passe',
                      color: NeonColors.info,
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                    _SettingsTile(
                      icon: Icons.devices,
                      title: 'Sessions actives',
                      subtitle: '${ref.watch(sessionsProvider).sessions.length} appareil(s)',
                      color: NeonColors.info,
                      onTap: () => _showSessionsSheet(context),
                    ),
                    _SettingsTile(
                      icon: Icons.fingerprint,
                      title: 'Biométrie',
                      subtitle: ref.watch(biometricStateProvider).when(
                        data: (state) => state.isAvailable
                            ? 'Activée'
                            : state.canCheck
                                ? 'Désactivée'
                                : 'Non disponible',
                        loading: () => 'Vérification...',
                        error: (_, __) => 'Erreur',
                      ),
                      color: ref.watch(biometricStateProvider).when(
                        data: (state) => state.isAvailable
                            ? NeonColors.success
                            : NeonColors.textMuted,
                        loading: () => NeonColors.textMuted,
                        error: (_, __) => NeonColors.error,
                      ),
                      trailing: ref.watch(biometricStateProvider).when(
                        data: (state) => state.canCheck
                            ? Switch(
                                value: state.isEnabled,
                                onChanged: (value) async {
                                  final service = ref.read(biometricServiceProvider);
                                  if (value) {
                                    // Tester l'authentification avant d'activer
                                    final result = await service.authenticateWithResult(
                                      reason: 'Authentifiez-vous pour activer la biométrie',
                                    );
                                    if (result.success) {
                                      await service.setBiometricEnabled(true);
                                      ref.invalidate(biometricStateProvider);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Biométrie activée'),
                                            backgroundColor: NeonColors.success,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(result.error ?? 'Erreur'),
                                            backgroundColor: NeonColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    await service.setBiometricEnabled(false);
                                    ref.invalidate(biometricStateProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Biométrie désactivée'),
                                          backgroundColor: NeonColors.textSecondary,
                                        ),
                                      );
                                    }
                                  }
                                },
                                activeThumbColor: NeonColors.success,
                              )
                            : null,
                        loading: () => const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, __) => null,
                      ),
                      onTap: () async {
                        final state = await ref.read(biometricStateProvider.future);
                        if (!state.canCheck) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Biométrie non disponible sur cet appareil'),
                                backgroundColor: NeonColors.warning,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // À PROPOS
                  _buildSection('À PROPOS', [
                    _SettingsTile(
                      icon: Icons.description,
                      title: 'Conditions générales',
                      color: NeonColors.textSecondary,
                      onTap: () => context.push('/legal/terms'),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip,
                      title: 'Politique de confidentialité',
                      color: NeonColors.textSecondary,
                      onTap: () => context.push('/legal/privacy'),
                    ),
                    _SettingsTile(
                      icon: Icons.info,
                      title: 'Version',
                      subtitle: '1.0.0 (build 42)',
                      color: NeonColors.textSecondary,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: NeonColors.card,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('WIWIGA', style: TextStyle(color: NeonColors.textPrimary, fontWeight: FontWeight.bold)),
                            content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Version 1.0.0 (build 42)', style: TextStyle(color: NeonColors.textSecondary)),
                              SizedBox(height: 12),
                              Text('© 2026 WIWIGA Team', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
                              SizedBox(height: 8),
                              Text('Plateforme de jeux de société en ligne', style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
                            ],),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer', style: TextStyle(color: NeonColors.primary))),
                            ],
                          ),
                        );
                      },
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

  // === DIALOGS ===

  void _showChangePasswordDialog(BuildContext context) {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: NeonColors.surface,
          title: const Text('Changer le mot de passe',
              style: TextStyle(color: NeonColors.textPrimary, fontSize: 16),),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(oldController, 'Ancien mot de passe', Icons.lock_outline, isPassword: true),
                const SizedBox(height: 12),
                _buildDialogField(newController, 'Nouveau mot de passe', Icons.lock, isPassword: true),
                const SizedBox(height: 12),
                _buildDialogField(confirmController, 'Confirmer', Icons.lock_outline, isPassword: true),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(error!, style: const TextStyle(color: NeonColors.error, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary)),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final old = oldController.text.trim();
                      final newP = newController.text.trim();
                      final confirm = confirmController.text.trim();

                      if (old.isEmpty || newP.isEmpty) {
                        setDialogState(() => error = 'Tous les champs sont requis');
                        return;
                      }
                      if (newP.length < 8) {
                        setDialogState(() => error = 'Minimum 8 caractères');
                        return;
                      }
                      if (newP != confirm) {
                        setDialogState(() => error = 'Les mots de passe ne correspondent pas');
                        return;
                      }

                      setDialogState(() => isLoading = true);
                      try {
                        await ref.read(profileRepositoryProvider).changePassword(
                              oldPassword: old,
                              newPassword: newP,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          _showSnackbar(context, 'Mot de passe modifié !');
                        }
                      } catch (e, st) {
                        ErrorHandler.logError(e, st, context: 'Settings.changePassword');
                        setDialogState(() {
                          isLoading = false;
                          error = ErrorHandler.userMessage(e);
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: NeonColors.primary))
                  : const Text('Modifier', style: TextStyle(color: NeonColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NeonColors.textSecondary, fontSize: 13),
        prefixIcon: Icon(icon, color: NeonColors.primary, size: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NeonColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: NeonColors.primary, width: 2),
        ),
        filled: true,
        fillColor: NeonColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showSessionsSheet(BuildContext context) {
    final sessionsState = ref.read(sessionsProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: NeonColors.border, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                const Text('Sessions actives',
                    style: TextStyle(color: NeonColors.textPrimary, fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold),),
                const SizedBox(height: 16),
                if (sessionsState.sessions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Aucune session active', style: TextStyle(color: NeonColors.textSecondary)),
                  )
                else
                  ...sessionsState.sessions.map((session) {
                    final isCurrent = session['is_current'] == true;
                    final deviceName = session['device_name'] ?? session['user_agent'] ?? 'Appareil inconnu';
                    final lastActive = session['last_active_at'] != null
                        ? DateTime.tryParse(session['last_active_at'])
                        : null;
                    final timeStr = lastActive != null ? _formatTimeAgo(lastActive) : 'Récemment';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NeonColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCurrent ? NeonColors.primary.withValues(alpha: 0.4) : NeonColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCurrent ? Icons.computer : Icons.devices_other,
                            color: isCurrent ? NeonColors.primary : NeonColors.textSecondary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(deviceName,
                                        style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),),
                                    if (isCurrent) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: NeonColors.primary.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('ACTUEL', style: TextStyle(color: NeonColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(timeStr, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 10)),
                              ],
                            ),
                          ),
                          if (!isCurrent)
                            IconButton(
                              icon: const Icon(Icons.logout, color: NeonColors.error, size: 18),
                              onPressed: () async {
                                final sessionId = session['id']?.toString() ?? '';
                                if (sessionId.isNotEmpty) {
                                  final success = await ref.read(sessionsProvider.notifier).revokeSession(sessionId);
                                  if (success) {
                                    setSheetState(() {});
                                  }
                                }
                              },
                              tooltip: 'Révoquer',
                            ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // === WIDGETS ===

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
      if (context.mounted) {
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
          IconButton(
            icon: const Icon(Icons.arrow_back, color: NeonColors.primary),
            tooltip: 'Retour',
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
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

  Widget _buildBoolToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return _SettingsTile(
      icon: icon,
      title: title,
      color: color,
      trailing: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            color: value ? color.withValues(alpha: 0.3) : NeonColors.border,
            border: Border.all(color: value ? color : NeonColors.textSecondary),
          ),
          padding: const EdgeInsets.all(2),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value ? color : NeonColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
      onTap: () => onChanged(!value),
    );
  }

  Widget _buildSelectTile({
    required IconData icon,
    required String title,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onSelect,
    required Color color,
  }) {
    return _SettingsTile(
      icon: icon,
      title: title,
      subtitle: value,
      color: color,
      trailing: DropdownButton<String>(
        value: options.entries.firstWhere((e) => e.value == value).key,
        underline: const SizedBox(),
        dropdownColor: NeonColors.surface,
        style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12),
        items: options.entries.map((e) {
          return DropdownMenuItem<String>(
            value: e.key,
            child: Text(e.value, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12)),
          );
        }).toList(),
        onChanged: (v) {
          if (v != null) onSelect(v);
        },
      ),
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
      if (!context.mounted) return;
      if (success) {
        ref.read(otpRequiredProvider.notifier).state = newValue;
        _showSnackbar(context, newValue ? 'OTP activé' : 'OTP désactivé');
      } else {
        _showSnackbar(context, 'Erreur de mise à jour');
      }
    });
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

  String _themeLabel(String theme) {
    switch (theme) {
      case 'neon': return 'Néon';
      case 'dark': return 'Sombre';
      case 'light': return 'Clair';
      default: return theme;
    }
  }

  String _fontSizeLabel(String size) {
    switch (size) {
      case 'small': return 'Petit';
      case 'medium': return 'Moyen';
      case 'large': return 'Grand';
      default: return size;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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
