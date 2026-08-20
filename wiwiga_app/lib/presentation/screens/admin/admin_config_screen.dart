// ============================================================
// Fichier: admin_config_screen.dart
// Description: Configuration admin (paiements, thème, features, tokens)
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/config_provider.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../widgets/admin/empty_state.dart';
import '../../widgets/admin/admin_feedback.dart';

/// Écran de configuration admin
/// Permet de modifier les paramètres globaux de la plateforme
class AdminConfigScreen extends ConsumerStatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  ConsumerState<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends ConsumerState<AdminConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              const Text('Accès non autorisé',
                  style: TextStyle(color: NeonColors.textPrimary, fontSize: 20),),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Retour'),),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        backgroundColor: NeonColors.surface,
        title: const Text('Services App',
            style: TextStyle(fontWeight: FontWeight.bold),),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: NeonColors.accent),
            tooltip: 'Voir l\'historique',
            onPressed: () => _showConfigHistory(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: NeonColors.primary,
          labelColor: NeonColors.primary,
          unselectedLabelColor: NeonColors.textMuted,
          tabs: const [
            Tab(text: 'Paiements'),
            Tab(text: 'Thème'),
            Tab(text: 'Features'),
            Tab(text: 'Tokens'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Bannière de navigation vers l'écran dédié Jeux
          _GamesConfigRedirectBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PaymentsConfigTab(),
                _ThemeConfigTab(),
                _FeaturesConfigTab(),
                _TokensConfigTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConfigHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.card,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: NeonColors.accent),
                  const SizedBox(width: 8),
                  const Text('Historique des changements',
                    style: TextStyle(color: NeonColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: NeonColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadHistory(ref),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const NeonLoadingSpinner.center();
                    }
                    final history = snapshot.data ?? [];
                    if (history.isEmpty) {
                      return const Center(child: Text('Aucun changement récent',
                        style: TextStyle(color: NeonColors.textMuted),),);
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(color: NeonColors.border),
                      itemBuilder: (_, i) {
                        final entry = history[i];
                        return ListTile(
                          leading: const Icon(Icons.settings, color: NeonColors.primary, size: 20),
                          title: Text(entry['summary'] ?? entry['config_type'] ?? 'Modification',
                            style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14),),
                          subtitle: Text(entry['changed_at']?.toString() ?? '',
                            style: const TextStyle(color: NeonColors.textMuted, fontSize: 11),),
                          trailing: Text(entry['config_type'] ?? '',
                            style: const TextStyle(color: NeonColors.accent, fontSize: 11),),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadHistory(WidgetRef ref) async {
    try {
      final adminRepo = ref.read(adminRepositoryProvider);
      final result = await adminRepo.getConfigHistory(limit: 20);
      final logs = result['logs'] ?? result['history'] ?? [];
      if (logs is List) {
        return logs.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

/// Dialog de confirmation partagé pour les modifications de configuration
void _showConfigConfirmDialog(BuildContext context, String message, VoidCallback onConfirm) {
  showAdminConfirmDialog(
    context,
    title: 'Confirmer',
    message: message,
    confirmLabel: 'Confirmer',
    icon: Icons.save,
  ).then((confirmed) {
    if (confirmed) onConfirm();
  });
}

// ============================================================
// Bannière de redirection vers l'écran dédié Règles Jeux
// ============================================================
class _GamesConfigRedirectBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NeonColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: NeonColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sports_esports, color: NeonColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configuration des jeux',
                  style: TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Mises, commissions, limites et paramètres par jeu',
                  style: TextStyle(color: NeonColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: const Text('Gérer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: NeonColors.primary,
              foregroundColor: NeonColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => context.go('/admin/game-config'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Tab: Configuration Paiements (éditable)
// ============================================================
class _PaymentsConfigTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsConfig = ref.watch(paymentsConfigProvider);

    return paymentsConfig.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => AdminErrorState(error: 'Erreur: $e', onRetry: () => ref.invalidate(paymentsConfigProvider)),
      data: (config) {
        final providers = config.providers;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader(title: 'Providers de paiement', icon: Icons.payment),
            const SizedBox(height: 16),
            ...providers.entries.map((entry) {
              final prov = entry.value;
              return _PaymentProviderEditor(
                provider: prov,
                onSave: (updates) {
                  _showConfigConfirmDialog(context, 'Sauvegarder la configuration de ${prov.provider} ?', () {
                    ref.read(paymentsConfigProvider.notifier).updateProvider(prov.provider, updates);
                    context.showSuccess('Provider mis à jour');
                  });
                },
              );
            }),
            const SizedBox(height: 24),
            const _InfoBanner(
              message: 'Désactiver un provider empêche les dépôts/retraits via ce moyen.',
            ),
          ],
        );
      },
    );
  }
}

/// Éditeur pour un provider de paiement
class _PaymentProviderEditor extends StatefulWidget {
  final PaymentProviderConfigModel provider;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _PaymentProviderEditor({required this.provider, required this.onSave});

  @override
  State<_PaymentProviderEditor> createState() => _PaymentProviderEditorState();
}

class _PaymentProviderEditorState extends State<_PaymentProviderEditor> {
  late bool _isEnabled;
  late int _depositMin;
  late int _depositMax;
  late double _withdrawalFee;

  @override
  void initState() {
    super.initState();
    _isEnabled = widget.provider.isEnabled;
    _depositMin = widget.provider.depositMin;
    _depositMax = widget.provider.depositMax;
    _withdrawalFee = widget.provider.withdrawalFeePercent;
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.provider.provider.replaceAll('_', ' ').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isEnabled ? NeonColors.primary.withValues(alpha: 0.3) : NeonColors.border,),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: _isEnabled ? NeonColors.primary : NeonColors.textMuted),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(color: _isEnabled ? NeonColors.textPrimary : NeonColors.textMuted,
                fontSize: 16, fontWeight: FontWeight.bold,),),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isEnabled ? NeonColors.primary.withValues(alpha: 0.2) : NeonColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_isEnabled ? 'Actif' : 'Inactif',
                  style: TextStyle(color: _isEnabled ? NeonColors.primary : NeonColors.error, fontSize: 11, fontWeight: FontWeight.bold),),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle enabled
          Row(
            children: [
              Text('Provider actif', style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Switch(value: _isEnabled, onChanged: (v) => setState(() => _isEnabled = v),
                activeThumbColor: NeonColors.primary,),
            ],
          ),
          const SizedBox(height: 8),
          // Dépôt min
          _EditableLimitField(
            label: 'Dépôt min', value: _depositMin, suffix: ' FCFA',
            onSave: (v) => setState(() => _depositMin = v),
          ),
          // Dépôt max
          _EditableLimitField(
            label: 'Dépôt max', value: _depositMax, suffix: ' FCFA',
            onSave: (v) => setState(() => _depositMax = v),
          ),
          // Frais retrait
          Text('Frais retrait: ${_withdrawalFee.toStringAsFixed(1)}%',
            style: TextStyle(color: NeonColors.textSecondary, fontSize: 13),),
          Slider(value: _withdrawalFee, min: 0, max: 10, divisions: 20,
            activeColor: NeonColors.primary,
            onChanged: (v) => setState(() => _withdrawalFee = v),),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Sauvegarder'),
              style: ElevatedButton.styleFrom(backgroundColor: NeonColors.primary),
              onPressed: () => widget.onSave({
                'is_enabled': _isEnabled,
                'deposit_min': _depositMin,
                'deposit_max': _depositMax,
                'withdrawal_fee_percent': _withdrawalFee,
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Tab: Configuration Thème (éditable)
// ============================================================
class _ThemeConfigTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref.watch(themeConfigProvider);

    return themeConfig.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => AdminErrorState(error: 'Erreur: $e', onRetry: () => ref.invalidate(themeConfigProvider)),
      data: (config) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Apparence', icon: Icons.palette),
          const SizedBox(height: 16),
          // Couleurs
          _ConfigCard(
            title: 'Couleurs',
            subtitle: 'Palette de couleurs de l\'application',
            fields: [
              _ConfigField(label: 'Couleur principale', value: config.primaryColor, icon: Icons.color_lens, color: _parseColor(config.primaryColor)),
              _ConfigField(label: 'Couleur secondaire', value: config.secondaryColor, icon: Icons.color_lens, color: _parseColor(config.secondaryColor)),
              _ConfigField(label: 'Couleur accent', value: config.accentColor, icon: Icons.color_lens, color: _parseColor(config.accentColor)),
            ],
          ),
          const SizedBox(height: 12),
          // Color pickers éditables
          _ColorEditRow(
            label: 'Couleur principale',
            currentColor: config.primaryColor,
            onColorChanged: (c) {
              ref.read(themeConfigProvider.notifier).updateConfig({'primary_color': c});
              _snack(context);
            },
          ),
          _ColorEditRow(
            label: 'Couleur secondaire',
            currentColor: config.secondaryColor,
            onColorChanged: (c) {
              ref.read(themeConfigProvider.notifier).updateConfig({'secondary_color': c});
              _snack(context);
            },
          ),
          _ColorEditRow(
            label: 'Couleur accent',
            currentColor: config.accentColor,
            onColorChanged: (c) {
              ref.read(themeConfigProvider.notifier).updateConfig({'accent_color': c});
              _snack(context);
            },
          ),
          const SizedBox(height: 16),
          // Interface
          _ConfigCard(
            title: 'Interface',
            subtitle: 'Paramètres d\'affichage',
            fields: [
              _ConfigField(label: 'Border radius', value: '${config.borderRadius.toInt()}px', icon: Icons.rounded_corner),
              _ConfigField(label: 'Glow intensity', value: '${(config.glowIntensity * 100).toInt()}%', icon: Icons.brightness_7),
              _ConfigField(label: 'Animation duration', value: '${config.animationDuration}ms', icon: Icons.animation),
              _ConfigField(label: 'Police body', value: config.fontFamilyBody, icon: Icons.text_fields),
              _ConfigField(label: 'Police display', value: config.fontFamilyDisplay, icon: Icons.text_fields),
            ],
          ),
          const SizedBox(height: 12),
          // Slider border radius
          _SliderEditRow(
            label: 'Border radius',
            value: config.borderRadius,
            min: 0, max: 24, divisions: 24, suffix: 'px',
            onChanged: (v) {
              ref.read(themeConfigProvider.notifier).updateConfig({'border_radius': v});
              _snack(context);
            },
          ),
          _SliderEditRow(
            label: 'Glow intensity',
            value: config.glowIntensity,
            min: 0, max: 1, divisions: 20, suffix: '%',
            displayMultiplier: 100,
            onChanged: (v) {
              ref.read(themeConfigProvider.notifier).updateConfig({'glow_intensity': v});
              _snack(context);
            },
          ),
          _SliderEditRow(
            label: 'Animation duration',
            value: config.animationDuration.toDouble(),
            min: 0, max: 1000, divisions: 20, suffix: 'ms',
            onChanged: (v) {
              ref.read(themeConfigProvider.notifier).updateConfig({'animation_duration': v.round()});
              _snack(context);
            },
          ),
          const SizedBox(height: 24),
          const _InfoBanner(
            message: 'Les modifications de thème sont appliquées en temps réel.',
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context) {
    context.showSuccess('Thème mis à jour');
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return NeonColors.primary;
    }
  }
}

/// Row avec color picker hex
class _ColorEditRow extends StatefulWidget {
  final String label;
  final String currentColor;
  final ValueChanged<String> onColorChanged;

  const _ColorEditRow({required this.label, required this.currentColor, required this.onColorChanged});

  @override
  State<_ColorEditRow> createState() => _ColorEditRowState();
}

class _ColorEditRowState extends State<_ColorEditRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentColor);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color preview;
    try {
      preview = Color(int.parse(widget.currentColor.replaceFirst('#', '0xFF')));
    } catch (_) {
      preview = NeonColors.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: preview, shape: BoxShape.circle,
            border: Border.all(color: NeonColors.border),),),
          const SizedBox(width: 12),
          Text(widget.label, style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
          const Spacer(),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: NeonColors.textPrimary, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(borderSide: BorderSide(color: NeonColors.primary)),
              ),
              onSubmitted: (val) {
                final hex = val.trim();
                if (hex.startsWith('#') && hex.length == 7) {
                  widget.onColorChanged(hex);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Row avec slider éditable
class _SliderEditRow extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final double? displayMultiplier;
  final ValueChanged<double> onChanged;

  const _SliderEditRow({
    required this.label, required this.value, required this.min,
    required this.max, required this.divisions, required this.suffix,
    required this.onChanged, this.displayMultiplier,
  });

  @override
  State<_SliderEditRow> createState() => _SliderEditRowState();
}

class _SliderEditRowState extends State<_SliderEditRow> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final display = widget.displayMultiplier != null
        ? '${(_value * widget.displayMultiplier!).toInt()}${widget.suffix}'
        : '${_value.toInt()}${widget.suffix}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.label, style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
              const Spacer(),
              Text(display, style: const TextStyle(color: NeonColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: _value, min: widget.min, max: widget.max, divisions: widget.divisions,
            activeColor: NeonColors.primary,
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: widget.onChanged,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Tab: Configuration Features (connecté à l'API)
// ============================================================
class _FeaturesConfigTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featureConfig = ref.watch(featureConfigProvider);

    return featureConfig.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => AdminErrorState(error: 'Erreur: $e', onRetry: () => ref.invalidate(featureConfigProvider)),
      data: (config) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Fonctionnalités', icon: Icons.toggle_on),
          const SizedBox(height: 16),
          _InteractiveFeatureToggle(
            title: 'Mode maintenance',
            description: 'Active le mode maintenance (app inaccessible aux users)',
            isEnabled: config.maintenanceMode,
            color: NeonColors.error,
            onChanged: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'maintenance_mode': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          _InteractiveFeatureToggle(
            title: 'Inscriptions ouvertes',
            description: 'Permet aux nouveaux utilisateurs de s\'inscrire',
            isEnabled: config.registrationEnabled,
            color: NeonColors.primary,
            onChanged: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'registration_enabled': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          const _InteractiveFeatureToggle(
            title: 'PvP Enabled',
            description: 'Active les parties entre joueurs',
            isEnabled: true,
            color: NeonColors.primary,
            onChanged: null, // Lecture seule pour l'instant
          ),
          const _InteractiveFeatureToggle(
            title: 'Tournois',
            description: 'Active les tournois et compétitions',
            isEnabled: false,
            color: NeonColors.paymentOrange,
            onChanged: null,
          ),
          const _InteractiveFeatureToggle(
            title: 'Chat en jeu',
            description: 'Active le chat pendant les parties',
            isEnabled: true,
            color: NeonColors.adminCyan,
            onChanged: null,
          ),
          const _InteractiveFeatureToggle(
            title: 'Transferts de jetons',
            description: 'Permet aux joueurs de se transférer des jetons',
            isEnabled: true,
            color: NeonColors.adminPurple,
            onChanged: null,
          ),
          const SizedBox(height: 16),
          // Limites éditables
          const _SectionHeader(title: 'Limites financières', icon: Icons.money),
          const SizedBox(height: 16),
          _EditableLimitField(
            label: 'Dépôt minimum',
            value: config.minDepositAmount,
            suffix: ' FCFA',
            onSave: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'min_deposit_amount': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          _EditableLimitField(
            label: 'Dépôt maximum',
            value: config.maxDepositAmount,
            suffix: ' FCFA',
            onSave: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'max_deposit_amount': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          _EditableLimitField(
            label: 'Retrait minimum',
            value: config.minWithdrawalAmount,
            suffix: ' FCFA',
            onSave: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'min_withdrawal_amount': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          _EditableLimitField(
            label: 'Retrait maximum',
            value: config.maxWithdrawalAmount,
            suffix: ' FCFA',
            onSave: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'max_withdrawal_amount': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          _EditableLimitField(
            label: 'Seuil KYC',
            value: config.kycRequiredThreshold,
            suffix: ' FCFA',
            onSave: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'kyc_required_threshold': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          const SizedBox(height: 24),
          const _InfoBanner(
            message: 'Les modifications prennent effet immédiatement. Un historique est conservé.',
          ),
        ],
      ),
    );
  }

  void _showSaveConfirmation(BuildContext context, WidgetRef ref) {
    context.showSuccess('Configuration mise à jour');
  }
}

/// Toggle interactif connecté à l'API
class _InteractiveFeatureToggle extends StatelessWidget {
  final String title;
  final String description;
  final bool isEnabled;
  final Color color;
  final ValueChanged<bool>? onChanged;

  const _InteractiveFeatureToggle({
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.color,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isEnabled ? color.withValues(alpha: 0.3) : NeonColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: NeonColors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }
}

/// Champ de limite éditable
class _EditableLimitField extends StatefulWidget {
  final String label;
  final int value;
  final String suffix;
  final ValueChanged<int> onSave;

  const _EditableLimitField({
    required this.label,
    required this.value,
    required this.suffix,
    required this.onSave,
  });

  @override
  State<_EditableLimitField> createState() => _EditableLimitFieldState();
}

class _EditableLimitFieldState extends State<_EditableLimitField> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: NeonColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, color: NeonColors.primary, size: 16),
          const SizedBox(width: 12),
          Text(widget.label, style: TextStyle(color: NeonColors.textSecondary, fontSize: 13)),
          const Spacer(),
          if (_isEditing)
            SizedBox(
              width: 120,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  border: UnderlineInputBorder(borderSide: BorderSide(color: NeonColors.primary)),
                ),
                onSubmitted: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null) widget.onSave(parsed);
                  setState(() => _isEditing = false);
                },
              ),
            )
          else
            GestureDetector(
              onTap: () {
                setState(() {
                  _isEditing = true;
                  _controller.text = widget.value.toString();
                });
              },
              child: Text(
                '${widget.value}${widget.suffix}',
                style: const TextStyle(color: NeonColors.primary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// Tab: Configuration Tokens (éditable)
// ============================================================
class _TokensConfigTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensConfig = ref.watch(tokensConfigProvider);

    return tokensConfig.when(
      loading: () => const NeonLoadingSpinner.center(),
      error: (e, _) => AdminErrorState(error: 'Erreur: $e', onRetry: () => ref.invalidate(tokensConfigProvider)),
      data: (config) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Jetons virtuels', icon: Icons.monetization_on),
          const SizedBox(height: 16),
          _ConfigCard(
            title: 'Taux de change',
            subtitle: 'Conversion FCFA ↔ Jetons',
            fields: [
              _ConfigField(label: 'Taux exchange', value: '${config.exchangeRate} tokens/FCFA', icon: Icons.swap_horiz),
              _ConfigField(label: 'Frais exchange', value: '${config.exchangeFeePercent.toStringAsFixed(1)}%', icon: Icons.percent),
              _ConfigField(label: 'Frais fixe', value: '${config.exchangeFixedFee} FCFA', icon: Icons.money),
            ],
          ),
          const SizedBox(height: 12),
          // Taux de change éditable
          _EditableLimitField(
            label: 'Taux tokens/FCFA', value: config.exchangeRate, suffix: ' tokens',
            onSave: (v) {
              _showConfigConfirmDialog(context, 'Sauvegarder cette modification ?', () {
                ref.read(tokensConfigProvider.notifier).updateConfig({'exchange_rate': v});
                context.showSuccess('Configuration tokens mise à jour');
              });
            },
          ),
          _EditableLimitField(
            label: 'Frais fixe exchange', value: config.exchangeFixedFee, suffix: ' FCFA',
            onSave: (v) {
              _showConfigConfirmDialog(context, 'Sauvegarder cette modification ?', () {
                ref.read(tokensConfigProvider.notifier).updateConfig({'exchange_fixed_fee': v});
                context.showSuccess('Configuration tokens mise à jour');
              });
            },
          ),
          const SizedBox(height: 16),
          _ConfigCard(
            title: 'Limites',
            subtitle: 'Limites d\'achat et de transfert',
            fields: [
              _ConfigField(label: 'Achat journalier max', value: '${config.dailyPurchaseLimit} FCFA', icon: Icons.shopping_cart),
              _ConfigField(label: 'Transfert journalier max', value: '${config.dailyTransferLimit} tokens', icon: Icons.send),
              _ConfigField(label: 'Frais cadeau', value: '${config.giftFeePercent.toStringAsFixed(1)}%', icon: Icons.card_giftcard),
            ],
          ),
          const SizedBox(height: 12),
          _EditableLimitField(
            label: 'Achat journalier max', value: config.dailyPurchaseLimit, suffix: ' FCFA',
            onSave: (v) => _confirmAndSaveInline(context, ref, 'daily_purchase_limit', v),
          ),
          _EditableLimitField(
            label: 'Transfert journalier max', value: config.dailyTransferLimit, suffix: ' tokens',
            onSave: (v) => _confirmAndSaveInline(context, ref, 'daily_transfer_limit', v),
          ),
          const SizedBox(height: 16),
          _ConfigCard(
            title: 'Mise minimum jetons',
            subtitle: 'Mises minimum en jetons par type de jeu',
            fields: [
              _ConfigField(label: 'Dés', value: '${config.diceMinBet} tokens', icon: Icons.casino),
              _ConfigField(label: 'Cartes', value: '${config.cardsMinBet} tokens', icon: Icons.style),
            ],
          ),
          const SizedBox(height: 12),
          _EditableLimitField(
            label: 'Dés min', value: config.diceMinBet, suffix: ' tokens',
            onSave: (v) => _confirmAndSaveInline(context, ref, 'dice_min_bet', v),
          ),
          _EditableLimitField(
            label: 'Cartes min', value: config.cardsMinBet, suffix: ' tokens',
            onSave: (v) => _confirmAndSaveInline(context, ref, 'cards_min_bet', v),
          ),
          const SizedBox(height: 24),
          const _InfoBanner(
            message: 'Les modifications de tokens prennent effet immédiatement.',
          ),
        ],
      ),
    );
  }
}

/// Helper inline pour tokens - confirmation + sauvegarde
void _confirmAndSaveInline(BuildContext context, WidgetRef ref, String key, int value) {
  _showConfigConfirmDialog(context, 'Sauvegarder cette modification ?', () {
    ref.read(tokensConfigProvider.notifier).updateConfig({key: value});
    context.showSuccess('Configuration tokens mise à jour');
  });
}

// ============================================================
// Widgets helpers
// ============================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: NeonColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                color: NeonColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold,),),
      ],
    );
  }
}

class _ConfigCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_ConfigField> fields;

  const _ConfigCard({
    required this.title,
    required this.subtitle,
    required this.fields,
  });

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
          Text(title,
              style: const TextStyle(
                  color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold,),),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: NeonColors.textMuted, fontSize: 12),),
          const SizedBox(height: 16),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(f.icon, color: NeonColors.primary, size: 16),
                    const SizedBox(width: 12),
                    Text(f.label,
                        style: TextStyle(color: NeonColors.textSecondary, fontSize: 13),),
                    const Spacer(),
                    if (f.color != null) ...[
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: f.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: NeonColors.border),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(f.value,
                        style: const TextStyle(
                            color: NeonColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500,),),
                  ],
                ),
              ),),
        ],
      ),
    );
  }
}

class _ConfigField {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _ConfigField({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
}



class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NeonColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NeonColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: NeonColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: NeonColors.textSecondary, fontSize: 13),),
          ),
        ],
      ),
    );
  }
}
