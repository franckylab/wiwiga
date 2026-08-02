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
                  style: TextStyle(color: Colors.white, fontSize: 20)),
              const SizedBox(height: 16),
              ElevatedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('Retour')),
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
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            Tab(text: 'Features'),
            Tab(text: 'Tokens'),
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
}

// ============================================================
// Tab: Configuration Jeux
// ============================================================
class _GamesConfigTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Paramètres des jeux', icon: Icons.casino),
        const SizedBox(height: 16),
        _ConfigCard(
          title: 'Jeu de Dés',
          subtitle: 'Configuration principale du jeu de dés',
          fields: [
            _ConfigField(label: 'Mise minimum', value: '100 FCFA', icon: Icons.money),
            _ConfigField(label: 'Mise maximum', value: '50 000 FCFA', icon: Icons.money_off),
            _ConfigField(label: 'Commission (%)', value: '5%', icon: Icons.percent),
            _ConfigField(label: 'Mode commission', value: 'Pourcentage', icon: Icons.settings),
            _ConfigField(label: 'Timeout (secondes)', value: '120s', icon: Icons.timer),
            _ConfigField(label: 'Max joueurs', value: '4', icon: Icons.people),
          ],
        ),
        const SizedBox(height: 16),
        _ConfigCard(
          title: 'Matchmaking',
          subtitle: 'Paramètres de mise en relation',
          fields: [
            _ConfigField(label: 'Timeout création', value: '60s', icon: Icons.timer),
            _ConfigField(label: 'Timeout join', value: '30s', icon: Icons.timer),
            _ConfigField(label: 'Timeout tour', value: '45s', icon: Icons.timer),
            _ConfigField(label: 'Inactivité jeu', value: '300s', icon: Icons.timer_off),
          ],
        ),
        const SizedBox(height: 24),
        _InfoBanner(
          message: 'Les modifications prennent effet immédiatement pour les nouvelles parties.',
        ),
      ],
    );
  }
}

// ============================================================
// Tab: Configuration Paiements
// ============================================================
class _PaymentsConfigTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Providers de paiement', icon: Icons.payment),
        const SizedBox(height: 16),
        _PaymentProviderCard(
          name: 'Campay',
          isEnabled: true,
          details: [
            _ConfigField(label: 'Dépôt min', value: '100 FCFA', icon: Icons.arrow_downward),
            _ConfigField(label: 'Dépôt max', value: '500 000 FCFA', icon: Icons.arrow_upward),
            _ConfigField(label: 'Frais retrait', value: '2%', icon: Icons.receipt),
          ],
        ),
        const SizedBox(height: 12),
        _PaymentProviderCard(
          name: 'MTN MoMo',
          isEnabled: true,
          details: [
            _ConfigField(label: 'Dépôt min', value: '100 FCFA', icon: Icons.arrow_downward),
            _ConfigField(label: 'Dépôt max', value: '1 000 000 FCFA', icon: Icons.arrow_upward),
            _ConfigField(label: 'Frais retrait', value: '1.5%', icon: Icons.receipt),
          ],
        ),
        const SizedBox(height: 12),
        _PaymentProviderCard(
          name: 'Orange Money',
          isEnabled: false,
          details: [
            _ConfigField(label: 'Dépôt min', value: '100 FCFA', icon: Icons.arrow_downward),
            _ConfigField(label: 'Dépôt max', value: '500 000 FCFA', icon: Icons.arrow_upward),
            _ConfigField(label: 'Frais retrait', value: '2%', icon: Icons.receipt),
          ],
        ),
        const SizedBox(height: 24),
        _InfoBanner(
          message: 'Désactiver un provider empêche les dépôts/retraits via ce moyen.',
        ),
      ],
    );
  }
}

// ============================================================
// Tab: Configuration Thème
// ============================================================
class _ThemeConfigTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Apparence', icon: Icons.palette),
        const SizedBox(height: 16),
        _ConfigCard(
          title: 'Couleurs',
          subtitle: 'Palette de couleurs de l\'application',
          fields: [
            _ConfigField(label: 'Couleur principale', value: '#00FF88', icon: Icons.color_lens, color: const Color(0xFF00FF88)),
            _ConfigField(label: 'Couleur accent', value: '#FF00FF', icon: Icons.color_lens, color: const Color(0xFFFF00FF)),
            _ConfigField(label: 'Couleur erreur', value: '#FF4444', icon: Icons.color_lens, color: const Color(0xFFFF4444)),
          ],
        ),
        const SizedBox(height: 16),
        _ConfigCard(
          title: 'Interface',
          subtitle: 'Paramètres d\'affichage',
          fields: [
            _ConfigField(label: 'Mode sombre', value: 'Activé', icon: Icons.dark_mode),
            _ConfigField(label: 'Taille police', value: 'Moyenne', icon: Icons.text_fields),
            _ConfigField(label: 'Animations', value: 'Activées', icon: Icons.animation),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// Tab: Configuration Features
// ============================================================
class _FeaturesConfigTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Fonctionnalités', icon: Icons.toggle_on),
        const SizedBox(height: 16),
        _FeatureToggle(
          title: 'Mode maintenance',
          description: 'Active le mode maintenance (app inaccessible aux users)',
          isEnabled: false,
          color: Colors.redAccent,
        ),
        _FeatureToggle(
          title: 'PvP Enabled',
          description: 'Active les parties entre joueurs',
          isEnabled: true,
          color: const Color(0xFF00FF88),
        ),
        _FeatureToggle(
          title: 'Tournois',
          description: 'Active les tournois et compétitions',
          isEnabled: false,
          color: const Color(0xFFFF6600),
        ),
        _FeatureToggle(
          title: 'Chat en jeu',
          description: 'Active le chat pendant les parties',
          isEnabled: true,
          color: const Color(0xFF00FFFF),
        ),
        _FeatureToggle(
          title: 'Transferts de jetons',
          description: 'Permet aux joueurs de se transférer des jetons',
          isEnabled: true,
          color: const Color(0xFFAA00FF),
        ),
        _FeatureToggle(
          title: 'Cadeaux entre amis',
          description: 'Permet d\'envoyer des jetons en cadeau',
          isEnabled: true,
          color: const Color(0xFFFF00FF),
        ),
      ],
    );
  }
}

// ============================================================
// Tab: Configuration Tokens
// ============================================================
class _TokensConfigTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _SectionHeader(title: 'Jetons virtuels', icon: Icons.monetization_on),
        const SizedBox(height: 16),
        _ConfigCard(
          title: 'Taux de change',
          subtitle: 'Conversion FCFA ↔ Jetons',
          fields: [
            _ConfigField(label: 'Taux exchange', value: '10 tokens/FCFA', icon: Icons.swap_horiz),
            _ConfigField(label: 'Frais exchange (%)', value: '2%', icon: Icons.percent),
            _ConfigField(label: 'Frais fixe', value: '0 FCFA', icon: Icons.money),
          ],
        ),
        const SizedBox(height: 16),
        _ConfigCard(
          title: 'Limites',
          subtitle: 'Limites d\'achat et de transfert',
          fields: [
            _ConfigField(label: 'Achat journalier max', value: '50 000 FCFA', icon: Icons.shopping_cart),
            _ConfigField(label: 'Transfert journalier max', value: '10 000 tokens', icon: Icons.send),
            _ConfigField(label: 'Frais cadeau', value: '5%', icon: Icons.card_giftcard),
          ],
        ),
        const SizedBox(height: 16),
        _ConfigCard(
          title: 'Mise minimum jetons',
          subtitle: 'Mises minimum en jetons par type de jeu',
          fields: [
            _ConfigField(label: 'Dés', value: '10 tokens', icon: Icons.casino),
            _ConfigField(label: 'Cartes', value: '20 tokens', icon: Icons.style),
          ],
        ),
      ],
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
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 16),
          ...fields.map((f) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(f.icon, color: const Color(0xFF00FF88), size: 16),
                    const SizedBox(width: 12),
                    Text(f.label,
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
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
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              )),
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
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEnabled
              ? const Color(0xFF00FF88).withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment,
                  color: isEnabled ? const Color(0xFF00FF88) : Colors.white38),
              const SizedBox(width: 8),
              Text(name,
                  style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.white38,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? const Color(0xFF00FF88).withOpacity(0.2)
                      : Colors.redAccent.withOpacity(0.2),
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
                              color: Colors.white.withOpacity(0.6), fontSize: 12)),
                      const Spacer(),
                      Text(f.value,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )),
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isEnabled ? color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
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
        color: const Color(0xFF00FF88).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF00FF88).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF00FF88), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message,
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
