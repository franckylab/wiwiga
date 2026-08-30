// ============================================================
// Fichier: admin_config_screen.dart
// Description: Configuration admin (jeux, paiements, thème, features, tokens)
// Auteur: WIWIGA Team
// Date: 2026-08-01
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/config_provider.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
        backgroundColor: const Color(0xFF0A0A1A),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.redAccent, size: 64),
              const SizedBox(height: 16),
              const Text('Accès non autorisé',
                  style: TextStyle(color: Colors.white, fontSize: 20),),
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
      backgroundColor: const Color(0xFF0A0A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/admin'),
        ),
        title: const Text('Configuration',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF00D9FF)),
            tooltip: 'Voir l\'historique',
            onPressed: () => _showConfigHistory(context, ref),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFF00FF88),
          labelColor: const Color(0xFF00FF88),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Jeux'),
            Tab(text: 'Paiements'),
            Tab(text: 'Thème'),
            Tab(text: 'Fonctionnalités'),
            Tab(text: 'Wiga'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GamesConfigTab(),
          _PaymentsConfigTab(),
          _ThemeConfigTab(),
          _FeaturesConfigTab(),
          _TokensConfigTab(),
        ],
      ),
    );
  }

  void _showConfigHistory(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
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
                  const Icon(Icons.history, color: Color(0xFF00D9FF)),
                  const SizedBox(width: 8),
                  const Text('Historique des changements',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadHistory(ref),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)));
                    }
                    final history = snapshot.data ?? [];
                    if (history.isEmpty) {
                      return const Center(child: Text('Aucun changement récent',
                        style: TextStyle(color: Colors.white54),),);
                    }
                    return ListView.separated(
                      controller: scrollController,
                      itemCount: history.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white12),
                      itemBuilder: (_, i) {
                        final entry = history[i];
                        return ListTile(
                          leading: const Icon(Icons.settings, color: Color(0xFF00FF88), size: 20),
                          title: Text(entry['summary'] ?? entry['config_type'] ?? 'Modification',
                            style: const TextStyle(color: Colors.white, fontSize: 14),),
                          subtitle: Text(entry['changed_at']?.toString() ?? '',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),),
                          trailing: Text(entry['config_type'] ?? '',
                            style: const TextStyle(color: Color(0xFF00D9FF), fontSize: 11),),
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

// ============================================================
// Tab: Configuration Jeux (éditable)
// ============================================================
class _GamesConfigTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesConfig = ref.watch(gamesConfigProvider);

    return gamesConfig.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.red))),
      data: (config) {
        final gameTypes = config.gameTypes;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionHeader(title: 'Paramètres des jeux', icon: Icons.casino),
            const SizedBox(height: 16),
            // Cartes de chaque type de jeu
            ...gameTypes.entries.map((entry) {
              final game = entry.value;
              return _GameTypeEditor(
                gameType: game,
                onSave: (updates) {
                  _showConfirmDialog(context, 'Sauvegarder la configuration de ${game.type} ?', () {
                    ref.read(gamesConfigProvider.notifier).updateGameType(game.type, updates);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Configuration jeu mise à jour'), backgroundColor: Color(0xFF00FF88)),
                    );
                  });
                },
              );
            }),
            const SizedBox(height: 16),
            // Matchmaking timeouts
            _ConfigCard(
              title: 'Matchmaking',
              subtitle: 'Paramètres de mise en relation',
              fields: [
                _ConfigField(label: 'Timeout création', value: '${config.matchmakingCreateTimeout}s', icon: Icons.timer),
                _ConfigField(label: 'Timeout join', value: '${config.matchmakingJoinTimeout}s', icon: Icons.timer),
                _ConfigField(label: 'Timeout tour', value: '${config.turnTimeout}s', icon: Icons.timer),
                _ConfigField(label: 'Inactivité jeu', value: '${config.inactivityTimeout}s', icon: Icons.timer_off),
              ],
            ),
            const SizedBox(height: 24),
            const _InfoBanner(
              message: 'Les modifications prennent effet immédiatement pour les nouvelles parties.',
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDialog(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmer', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: const Text('Confirmer', style: TextStyle(color: Color(0xFF0A0A1A))),
          ),
        ],
      ),
    );
  }
}

/// Éditeur pour un type de jeu (sliders + inputs)
class _GameTypeEditor extends StatefulWidget {
  final GameTypeConfigModel gameType;
  final ValueChanged<Map<String, dynamic>> onSave;

  const _GameTypeEditor({required this.gameType, required this.onSave});

  @override
  State<_GameTypeEditor> createState() => _GameTypeEditorState();
}

class _GameTypeEditorState extends State<_GameTypeEditor> {
  late int _minBet;
  late int _maxBet;
  late double _commission;
  late bool _isActive;
  late int _maxPlayers;

  @override
  void initState() {
    super.initState();
    // Backend désormais en wiga purs (migration 20260830000003)
    _minBet = widget.gameType.minBet;
    _maxBet = widget.gameType.maxBet;
    _commission = widget.gameType.commissionPercent;
    _isActive = widget.gameType.isActive;
    _maxPlayers = widget.gameType.maxPlayers;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _isActive ? const Color(0xFF00FF88).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.casino, color: Color(0xFF00FF88), size: 20),
              const SizedBox(width: 8),
              Text(widget.gameType.type.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isActive ? const Color(0xFF00FF88).withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_isActive ? 'Actif' : 'Inactif',
                  style: TextStyle(color: _isActive ? const Color(0xFF00FF88) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle actif/inactif
          Row(
            children: [
              Text('Jeu actif', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const Spacer(),
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v),
                activeThumbColor: const Color(0xFF00FF88),),
            ],
          ),
          const SizedBox(height: 8),
          // Slider mise min (wiga)
          Text('Mise minimum: $_minBet wiga', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          Slider(value: _minBet.toDouble(), min: 1, max: 100, divisions: 99,
            activeColor: const Color(0xFF00FF88),
            onChanged: (v) => setState(() => _minBet = v.round()),),
          // Slider mise max (wiga)
          Text('Mise maximum: $_maxBet wiga', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          Slider(value: _maxBet.toDouble(), min: 10, max: 5000, divisions: 100,
            activeColor: const Color(0xFF00FF88),
            onChanged: (v) => setState(() => _maxBet = v.round()),),
          // Slider commission
          Text('Commission: ${_commission.toStringAsFixed(1)}%', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          Slider(value: _commission, min: 0, max: 20, divisions: 40,
            activeColor: const Color(0xFF00FF88),
            onChanged: (v) => setState(() => _commission = v),),
          // Max joueurs
          Text('Max joueurs: $_maxPlayers', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          Row(
            children: [1, 2, 3, 4, 6].map((n) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('$n'),
                selected: _maxPlayers == n,
                selectedColor: const Color(0xFF00FF88).withValues(alpha: 0.3),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                labelStyle: TextStyle(color: _maxPlayers == n ? const Color(0xFF00FF88) : Colors.white54, fontSize: 12),
                onSelected: (sel) => setState(() => _maxPlayers = n),
              ),
            ),).toList(),
          ),
          const SizedBox(height: 12),
          // Bouton Sauvegarder
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Sauvegarder'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
              onPressed: () => widget.onSave({
                'min_bet': _minBet,
                'max_bet': _maxBet,
                'commission_percent': _commission,
                'is_active': _isActive,
                'max_players': _maxPlayers,
              }),
            ),
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
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.red))),
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
                  _showConfirmDialog(context, 'Sauvegarder la configuration de ${prov.provider} ?', () {
                    ref.read(paymentsConfigProvider.notifier).updateProvider(prov.provider, updates);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Provider mis à jour'), backgroundColor: Color(0xFF00FF88)),
                    );
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

  void _showConfirmDialog(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmer', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: const Text('Confirmer', style: TextStyle(color: Color(0xFF0A0A1A))),
          ),
        ],
      ),
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isEnabled ? const Color(0xFF00FF88).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: _isEnabled ? const Color(0xFF00FF88) : Colors.white38),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(color: _isEnabled ? Colors.white : Colors.white38,
                fontSize: 16, fontWeight: FontWeight.bold,),),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isEnabled ? const Color(0xFF00FF88).withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_isEnabled ? 'Actif' : 'Inactif',
                  style: TextStyle(color: _isEnabled ? const Color(0xFF00FF88) : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggle enabled
          Row(
            children: [
              Text('Provider actif', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const Spacer(),
              Switch(value: _isEnabled, onChanged: (v) => setState(() => _isEnabled = v),
                activeThumbColor: const Color(0xFF00FF88),),
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
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),),
          Slider(value: _withdrawalFee, min: 0, max: 10, divisions: 20,
            activeColor: const Color(0xFF00FF88),
            onChanged: (v) => setState(() => _withdrawalFee = v),),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.save, size: 16),
              label: const Text('Sauvegarder'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
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
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.red))),
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
              _ConfigField(label: 'Rayon bordure', value: '${config.borderRadius.toInt()}px', icon: Icons.rounded_corner),
              _ConfigField(label: 'Intensité éclat', value: '${(config.glowIntensity * 100).toInt()}%', icon: Icons.brightness_7),
              _ConfigField(label: 'Durée animation', value: '${config.animationDuration}ms', icon: Icons.animation),
              _ConfigField(label: 'Police body', value: config.fontFamilyBody, icon: Icons.text_fields),
              _ConfigField(label: 'Police display', value: config.fontFamilyDisplay, icon: Icons.text_fields),
            ],
          ),
          const SizedBox(height: 12),
          // Slider border radius
          _SliderEditRow(
            label: 'Rayon bordure',
            value: config.borderRadius,
            min: 0, max: 24, divisions: 24, suffix: 'px',
            onChanged: (v) {
              ref.read(themeConfigProvider.notifier).updateConfig({'border_radius': v});
              _snack(context);
            },
          ),
          _SliderEditRow(
            label: 'Intensité éclat',
            value: config.glowIntensity,
            min: 0, max: 1, divisions: 20, suffix: '%',
            displayMultiplier: 100,
            onChanged: (v) {
              ref.read(themeConfigProvider.notifier).updateConfig({'glow_intensity': v});
              _snack(context);
            },
          ),
          _SliderEditRow(
            label: 'Durée animation',
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thème mis à jour'), backgroundColor: Color(0xFF00FF88), duration: Duration(seconds: 2)),
    );
  }

  static Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF00FF88);
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
      preview = const Color(0xFF00FF88);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(width: 24, height: 24, decoration: BoxDecoration(color: preview, shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),),),
          const SizedBox(width: 12),
          Text(widget.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          const Spacer(),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
              const Spacer(),
              Text(display, style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: _value, min: widget.min, max: widget.max, divisions: widget.divisions,
            activeColor: const Color(0xFF00FF88),
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
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.red))),
      data: (config) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Fonctionnalités', icon: Icons.toggle_on),
          const SizedBox(height: 16),
          _InteractiveFeatureToggle(
            title: 'Mode maintenance',
            description: 'Active le mode maintenance (app inaccessible aux users)',
            isEnabled: config.maintenanceMode,
            color: Colors.redAccent,
            onChanged: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'maintenance_mode': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          _InteractiveFeatureToggle(
            title: 'Inscriptions ouvertes',
            description: 'Permet aux nouveaux utilisateurs de s\'inscrire',
            isEnabled: config.registrationEnabled,
            color: const Color(0xFF00FF88),
            onChanged: (val) {
              ref.read(featureConfigProvider.notifier).updateConfig({'registration_enabled': val});
              _showSaveConfirmation(context, ref);
            },
          ),
          const _InteractiveFeatureToggle(
            title: 'PvP activé',
            description: 'Active les parties entre joueurs',
            isEnabled: true,
            color: Color(0xFF00FF88),
            onChanged: null, // Lecture seule pour l'instant
          ),
          const _InteractiveFeatureToggle(
            title: 'Tournois',
            description: 'Active les tournois et compétitions',
            isEnabled: false,
            color: Color(0xFFFF6600),
            onChanged: null,
          ),
          const _InteractiveFeatureToggle(
            title: 'Chat en jeu',
            description: 'Active le chat pendant les parties',
            isEnabled: true,
            color: Color(0xFF00FFFF),
            onChanged: null,
          ),
          const _InteractiveFeatureToggle(
            title: 'Transferts de wiga',
            description: 'Permet aux joueurs de se transférer des wiga',
            isEnabled: true,
            color: Color(0xFFAA00FF),
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration mise à jour'),
        backgroundColor: Color(0xFF00FF88),
        duration: Duration(seconds: 2),
      ),
    );
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isEnabled ? color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onChanged,
            activeThumbColor: color,
            inactiveThumbColor: Colors.white.withValues(alpha: 0.3),
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, color: Color(0xFF00FF88), size: 16),
          const SizedBox(width: 12),
          Text(widget.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          const Spacer(),
          if (_isEditing)
            SizedBox(
              width: 120,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  border: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF88))),
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
                style: const TextStyle(color: Color(0xFF00FF88), fontSize: 13, fontWeight: FontWeight.w600),
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
      loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88))),
      error: (e, _) => Center(child: Text('Erreur: $e', style: const TextStyle(color: Colors.red))),
      data: (config) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionHeader(title: 'Wiga virtuels', icon: Icons.monetization_on),
          const SizedBox(height: 16),
          _ConfigCard(
            title: 'Taux de change',
            subtitle: 'Conversion FCFA ↔ Wiga',
            fields: [
              _ConfigField(label: 'Taux exchange', value: '${config.exchangeRate} wiga/FCFA', icon: Icons.swap_horiz),
              _ConfigField(label: 'Frais exchange', value: '${config.exchangeFeePercent.toStringAsFixed(1)}%', icon: Icons.percent),
              _ConfigField(label: 'Frais fixe', value: '${config.exchangeFixedFee} FCFA', icon: Icons.money),
            ],
          ),
          const SizedBox(height: 12),
          // Taux de change éditable
          _EditableLimitField(
            label: 'Taux wiga/FCFA', value: config.exchangeRate.toInt(), suffix: ' wiga',
            onSave: (v) {
              _confirmAndSave(context, ref, {'exchange_rate': v});
            },
          ),
          _EditableLimitField(
            label: 'Frais fixe exchange', value: config.exchangeFixedFee, suffix: ' FCFA',
            onSave: (v) {
              _confirmAndSave(context, ref, {'exchange_fixed_fee': v});
            },
          ),
          const SizedBox(height: 16),
          _ConfigCard(
            title: 'Limites',
            subtitle: 'Limites d\'achat et de transfert',
            fields: [
              _ConfigField(label: 'Achat journalier max', value: '${config.dailyPurchaseLimit} FCFA', icon: Icons.shopping_cart),
              _ConfigField(label: 'Transfert journalier max', value: '${config.dailyTransferLimit} wiga', icon: Icons.send),
              _ConfigField(label: 'Frais cadeau', value: '${config.giftFeePercent.toStringAsFixed(1)}%', icon: Icons.card_giftcard),
            ],
          ),
          const SizedBox(height: 12),
          _EditableLimitField(
            label: 'Achat journalier max', value: config.dailyPurchaseLimit, suffix: ' FCFA',
            onSave: (v) => _confirmAndSave(context, ref, {'daily_purchase_limit': v}),
          ),
          _EditableLimitField(
            label: 'Transfert journalier max', value: config.dailyTransferLimit, suffix: ' wiga',
            onSave: (v) => _confirmAndSave(context, ref, {'daily_transfer_limit': v}),
          ),
          const SizedBox(height: 16),
          _ConfigCard(
            title: 'Mise minimum wiga',
            subtitle: 'Mises minimum en wiga par type de jeu',
            fields: [
              _ConfigField(label: 'Dés', value: '${config.diceMinBet} wiga', icon: Icons.casino),
              _ConfigField(label: 'Cartes', value: '${config.cardsMinBet} wiga', icon: Icons.style),
            ],
          ),
          const SizedBox(height: 12),
          _EditableLimitField(
            label: 'Dés min', value: config.diceMinBet, suffix: ' wiga',
            onSave: (v) => _confirmAndSave(context, ref, {'dice_min_bet': v}),
          ),
          _EditableLimitField(
            label: 'Cartes min', value: config.cardsMinBet, suffix: ' wiga',
            onSave: (v) => _confirmAndSave(context, ref, {'cards_min_bet': v}),
          ),
          const SizedBox(height: 24),
          const _InfoBanner(
            message: 'Les modifications des wiga prennent effet immédiatement.',
          ),
        ],
      ),
    );
  }

  void _confirmAndSave(BuildContext context, WidgetRef ref, Map<String, dynamic> updates) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Confirmer', style: TextStyle(color: Colors.white)),
        content: const Text('Sauvegarder cette modification ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00FF88)),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tokensConfigProvider.notifier).updateConfig(updates);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuration wiga mise à jour'), backgroundColor: Color(0xFF00FF88)),
              );
            },
            child: const Text('Confirmer', style: TextStyle(color: Color(0xFF0A0A1A))),
          ),
        ],
      ),
    );
  }
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
        Icon(icon, color: const Color(0xFF00FF88), size: 24),
        const SizedBox(width: 12),
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,),),
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold,),),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),),
          const SizedBox(height: 16),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(f.icon, color: const Color(0xFF00FF88), size: 16),
                    const SizedBox(width: 12),
                    Text(f.label,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),),
                    const Spacer(),
                    if (f.color != null) ...[
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: f.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(f.value,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500,),),
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

class _PaymentProviderCard extends StatelessWidget {
  final String name;
  final bool isEnabled;
  final List<_ConfigField> details;

  const _PaymentProviderCard({
    required this.name,
    required this.isEnabled,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF00FF88).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment,
                  color: isEnabled ? const Color(0xFF00FF88) : Colors.white38,),
              const SizedBox(width: 8),
              Text(name,
                  style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,),),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? const Color(0xFF00FF88).withValues(alpha: 0.2)
                      : Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isEnabled ? 'Actif' : 'Inactif',
                  style: TextStyle(
                    color: isEnabled ? const Color(0xFF00FF88) : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (isEnabled) ...[
            const SizedBox(height: 12),
            ...details.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(f.icon, color: const Color(0xFF00FF88), size: 14),
                      const SizedBox(width: 8),
                      Text(f.label,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6), fontSize: 12,),),
                      const Spacer(),
                      Text(f.value,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500,),),
                    ],
                  ),
                ),),
          ],
        ],
      ),
    );
  }
}

class _FeatureToggle extends StatelessWidget {
  final String title;
  final String description;
  final bool isEnabled;
  final Color color;

  const _FeatureToggle({
    required this.title,
    required this.description,
    required this.isEnabled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontSize: 15, fontWeight: FontWeight.w600,),),
                const SizedBox(height: 4),
                Text(description,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5), fontSize: 12,),),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isEnabled ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isEnabled ? color : Colors.white24),
            ),
            child: Text(
              isEnabled ? 'ON' : 'OFF',
              style: TextStyle(
                color: isEnabled ? color : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;

  const _InfoBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF00FF88).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00FF88).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF00FF88), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),),
          ),
        ],
      ),
    );
  }
}
