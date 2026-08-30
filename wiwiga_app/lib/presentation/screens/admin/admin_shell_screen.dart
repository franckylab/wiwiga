// ============================================================
// Fichier: admin_shell_screen.dart
// Description: Shell de navigation admin avec sidebar expansible
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';
import '../../providers/admin_metrics_provider.dart';
import '../../providers/admin_ws_provider.dart';
import '../../widgets/admin/alert_badge.dart';
import '../../widgets/admin/admin_search_command.dart';

// ============================================================
// Modèle de navigation
// ============================================================

class _NavSection {
  final String title;
  final IconData icon;
  final List<_NavItem> items;

  const _NavSection({required this.title, required this.icon, required this.items});
}

class _NavItem {
  final String label;
  final String path;
  final IconData icon;

  const _NavItem({required this.label, required this.path, required this.icon});
}

// ============================================================
// Structure du menu — source de vérité unique
// ============================================================

const List<_NavSection> _navSections = [
  _NavSection(
    title: 'PILOTAGE',
    icon: Icons.speed,
    items: [
      _NavItem(label: 'Tableau de bord', path: '/admin', icon: Icons.dashboard_outlined),
      _NavItem(label: 'Métriques', path: '/admin/metrics', icon: Icons.bar_chart),
      _NavItem(label: 'Parties en direct', path: '/admin/games-live', icon: Icons.videogame_asset),
    ],
  ),
  _NavSection(
    title: 'ANALYTICS',
    icon: Icons.insights,
    items: [
      _NavItem(label: 'Revenus', path: '/admin/analytics/revenue', icon: Icons.monetization_on),
      _NavItem(label: 'Joueurs', path: '/admin/analytics/players', icon: Icons.people_outline),
      _NavItem(label: 'Jeux', path: '/admin/analytics/games', icon: Icons.sports_esports),
      _NavItem(label: 'Flux Monétaire', path: '/admin/analytics/monetary-flow', icon: Icons.swap_horiz),
      _NavItem(label: 'Richesse', path: '/admin/analytics/wealth', icon: Icons.account_tree),
    ],
  ),
  _NavSection(
    title: 'UTILISATEURS',
    icon: Icons.group,
    items: [
      _NavItem(label: 'Liste', path: '/admin/users', icon: Icons.people),
      _NavItem(label: 'CRM', path: '/admin/crm', icon: Icons.people_alt),
      _NavItem(label: 'Jeu Responsable', path: '/admin/responsible-gaming', icon: Icons.shield),
    ],
  ),
  _NavSection(
    title: 'CONFIGURATION',
    icon: Icons.tune,
    items: [
      _NavItem(label: 'Règles Jeux', path: '/admin/game-config', icon: Icons.tune),
      _NavItem(label: 'Services App', path: '/admin/config', icon: Icons.settings),
      _NavItem(label: 'Config. Plateforme', path: '/admin/platform-config', icon: Icons.settings_suggest),
      _NavItem(label: 'Progression & Niveaux', path: '/admin/player-progression', icon: Icons.emoji_events),
      _NavItem(label: 'Règles XP', path: '/admin/xp-rules', icon: Icons.stars),
      _NavItem(label: 'Sécurité', path: '/admin/security', icon: Icons.security),
      _NavItem(label: 'Notifications', path: '/admin/notifications', icon: Icons.notifications_outlined),
    ],
  ),
  _NavSection(
    title: 'OPÉRATIONS',
    icon: Icons.handyman,
    items: [
      _NavItem(label: 'Supervision', path: '/admin/monitoring', icon: Icons.monitor_heart),
      _NavItem(label: 'Réconciliation', path: '/admin/reconciliation', icon: Icons.account_balance),
      _NavItem(label: 'Bonus et Promos', path: '/admin/bonuses', icon: Icons.card_giftcard),
      _NavItem(label: 'Audit', path: '/admin/audit', icon: Icons.history),
      _NavItem(label: 'Rapports', path: '/admin/reports', icon: Icons.assessment),
      _NavItem(label: 'Alertes', path: '/admin/alerts', icon: Icons.notifications_active),
      _NavItem(label: 'Préférences Admin', path: '/admin/settings', icon: Icons.settings_applications),
    ],
  ),
];

// ============================================================
// Shell principal
// ============================================================

/// Shell de navigation admin avec sidebar expansible et badge notifications
class AdminShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> with SingleTickerProviderStateMixin {
  final Set<String> _expandedSections = {};
  late final AnimationController _sidebarAnim;

  @override
  void initState() {
    super.initState();
    _sidebarAnim = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..forward();

    Future.microtask(() {
      ref.read(adminAlertsProvider.notifier).loadUnreadCount();
      ref.read(adminWsProvider.notifier).connect();
    });

    // Auto-expand la section contenant la route active
    _autoExpandForPath(GoRouterState.of(context).uri.path);
  }

  @override
  void dispose() {
    _sidebarAnim.dispose();
    super.dispose();
  }

  void _autoExpandForPath(String path) {
    for (final section in _navSections) {
      for (final item in section.items) {
        if (path == item.path || (item.path != '/admin' && path.startsWith(item.path))) {
          _expandedSections.add(section.title);
          break;
        }
      }
    }
  }

  void _toggleSection(String title) {
    setState(() {
      if (_expandedSections.contains(title)) {
        _expandedSections.remove(title);
      } else {
        _expandedSections.add(title);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertsState = ref.watch(adminAlertsProvider);
    final wsState = ref.watch(adminWsProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    // Écouter les changements de route pour auto-expand
    // Mutation synchrone avant le rendu pour afficher la section active sans flash (collapse 1 frame)
    final currentPath = GoRouterState.of(context).uri.path;
    for (final section in _navSections) {
      for (final item in section.items) {
        if (currentPath == item.path || (item.path != '/admin' && currentPath.startsWith(item.path))) {
          _expandedSections.add(section.title);
          break;
        }
      }
    }

    return Scaffold(
      backgroundColor: NeonColors.background,
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(currentPath),
          Expanded(
            child: Column(
              children: [
                _buildHeader(alertsState, wsState, isDesktop),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !isDesktop ? _buildBottomNav(currentPath) : null,
    );
  }

  // ============================================================
  // Header
  // ============================================================

  Widget _buildHeader(AdminAlertsState alertsState, AdminWsState wsState, bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        border: Border(bottom: BorderSide(color: NeonColors.border)),
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu, color: NeonColors.textPrimary),
              onPressed: () => _showMobileDrawer(),
            ),
          const Text(
            'WIWIGA Admin',
            style: TextStyle(color: NeonColors.primary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: NeonColors.textSecondary, size: 20),
            onPressed: () => showAdminSearch(context),
            tooltip: 'Rechercher (Ctrl+K)',
          ),
          const SizedBox(width: 4),
          _WsIndicator(status: wsState.status),
          const SizedBox(width: 8),
          AdminAlertBadge(
            count: alertsState.unreadNotifications,
            child: IconButton(
              icon: const Icon(Icons.notifications_outlined, color: NeonColors.textSecondary),
              onPressed: () => context.go('/admin/notifications'),
            ),
          ),
          const SizedBox(width: 8),
          _buildProfileMenu(),
        ],
      ),
    );
  }

  Widget _buildProfileMenu() {
    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      color: NeonColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'logout') _confirmLogout();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'profile', child: Text('Profil', style: TextStyle(color: NeonColors.textPrimary))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'logout', child: Text('Déconnexion', style: TextStyle(color: Colors.red))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: NeonColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.admin_panel_settings, color: NeonColors.primary, size: 16),
            SizedBox(width: 4),
            Text('Admin', style: TextStyle(color: NeonColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, color: NeonColors.primary, size: 16),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NeonColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Déconnexion', style: TextStyle(color: NeonColors.textPrimary)),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?', style: TextStyle(color: NeonColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: NeonColors.textSecondary))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/auth');
            },
            child: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Sidebar desktop — sections expansibles
  // ============================================================

  Widget _buildSidebar(String currentPath) {
    return FadeTransition(
      opacity: _sidebarAnim,
      child: Container(
        width: 240,
        decoration: const BoxDecoration(
          color: NeonColors.surface,
          border: Border(right: BorderSide(color: NeonColors.border)),
        ),
        child: Column(
          children: [
            // Logo / branding
            _buildSidebarHeader(),
            // Navigation scrollable
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _navSections.length,
                itemBuilder: (context, index) => _buildSection(
                  _navSections[index],
                  currentPath,
                ),
              ),
            ),
            // Footer
            _buildSidebarFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [NeonColors.primary, NeonColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.grid_3x3, color: NeonColors.surface, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'WIWIGA',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: NeonColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(color: NeonColors.primary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: NeonColors.border)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: NeonColors.textMuted, size: 14),
          SizedBox(width: 8),
          Text(
            'v1.0.0',
            style: TextStyle(color: NeonColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Section expansible
  // ============================================================

  Widget _buildSection(_NavSection section, String currentPath) {
    final isExpanded = _expandedSections.contains(section.title);
    final hasActiveChild = section.items.any(
      (item) => currentPath == item.path || (item.path != '/admin' && currentPath.startsWith(item.path)),
    );

    return Column(
      children: [
        // Header de section
        _SectionHeader(
          title: section.title,
          icon: section.icon,
          isExpanded: isExpanded,
          hasActiveChild: hasActiveChild,
          onTap: () => _toggleSection(section.title),
        ),
        // Items avec animation
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: _SectionItems(
            items: section.items,
            currentPath: currentPath,
            onNavigate: () {},
          ),
          firstCurve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          secondCurve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          sizeCurve: Curves.easeOutCubic,
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  // ============================================================
  // Bottom nav (mobile)
  // ============================================================

  Widget _buildBottomNav(String currentPath) {
    return Container(
      decoration: const BoxDecoration(
        color: NeonColors.surface,
        border: Border(top: BorderSide(color: NeonColors.border)),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomNavItem(Icons.dashboard_outlined, 'Tableau de bord', '/admin', currentPath),
            _bottomNavItem(Icons.bar_chart, 'Métriques', '/admin/metrics', currentPath),
            _bottomNavItem(Icons.videogame_asset, 'En direct', '/admin/games-live', currentPath),
            _bottomNavItem(Icons.settings, 'Config', '/admin/config', currentPath),
            _bottomNavItem(Icons.more_horiz, 'Plus', '/admin/security', currentPath),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, String path, String currentPath) {
    final isActive = currentPath == path;
    return GestureDetector(
      onTap: () => context.go(path),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? NeonColors.primary : NeonColors.textMuted, size: 20),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: isActive ? NeonColors.primary : NeonColors.textMuted, fontSize: 10)),
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 20,
                height: 2,
                decoration: BoxDecoration(color: NeonColors.primary, borderRadius: BorderRadius.circular(1)),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Mobile drawer
  // ============================================================

  void _showMobileDrawer() {
    final currentPath = GoRouterState.of(context).uri.path;
    _autoExpandForPath(currentPath);

    showModalBottomSheet(
      context: context,
      backgroundColor: NeonColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          void toggleSection(String title) {
            setModalState(() {
              if (_expandedSections.contains(title)) {
                _expandedSections.remove(title);
              } else {
                _expandedSections.add(title);
              }
            });
            // Synchronise l'état du Shell pour persistance après fermeture du drawer
            setState(() {});
          }

          Widget buildDrawerSection(_NavSection section) {
            final isExpanded = _expandedSections.contains(section.title);
            final hasActiveChild = section.items.any(
              (item) => currentPath == item.path || (item.path != '/admin' && currentPath.startsWith(item.path)),
            );
            return Column(
              children: [
                _SectionHeader(
                  title: section.title,
                  icon: section.icon,
                  isExpanded: isExpanded,
                  hasActiveChild: hasActiveChild,
                  onTap: () => toggleSection(section.title),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: _SectionItems(
                    items: section.items,
                    currentPath: currentPath,
                    onNavigate: () {
                      if (Navigator.canPop(modalContext)) Navigator.pop(modalContext);
                    },
                  ),
                  firstCurve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                  secondCurve: const Interval(0.4, 1.0, curve: Curves.easeOut),
                  sizeCurve: Curves.easeOutCubic,
                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            );
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: NeonColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: NeonColors.border, borderRadius: BorderRadius.circular(2))),
                  ),
                  const Text(
                    'Navigation Admin',
                    style: TextStyle(color: NeonColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _navSections.length,
                      itemBuilder: (context, index) => buildDrawerSection(_navSections[index]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// Widgets de navigation — composables
// ============================================================

/// Header de section expansible avec animation du chevron
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isExpanded;
  final bool hasActiveChild;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.isExpanded,
    required this.hasActiveChild,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: hasActiveChild ? NeonColors.primary.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: hasActiveChild ? NeonColors.primary : NeonColors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: hasActiveChild ? NeonColors.primary : NeonColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: Icon(
                    Icons.expand_more,
                    color: hasActiveChild ? NeonColors.primary : NeonColors.textMuted,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Liste des items d'une section avec animation d'apparition
class _SectionItems extends StatelessWidget {
  final List<_NavItem> items;
  final String currentPath;
  final VoidCallback onNavigate;

  const _SectionItems({required this.items, required this.currentPath, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          _AnimatedNavItem(
            item: items[i],
            currentPath: currentPath,
            delay: i * 30,
            onTap: () {
              context.go(items[i].path);
              onNavigate();
            },
          ),
        const SizedBox(height: 2),
      ],
    );
  }
}

/// Item de navigation avec animation d'entrée décalée
class _AnimatedNavItem extends StatefulWidget {
  final _NavItem item;
  final String currentPath;
  final int delay;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.item,
    required this.currentPath,
    required this.delay,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _anim.forward();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.currentPath == widget.item.path ||
        (widget.item.path != '/admin' && widget.currentPath.startsWith(widget.item.path));

    return FadeTransition(
      opacity: _anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-0.1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: isActive ? NeonColors.primary.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isActive
                      ? const Border(left: BorderSide(color: NeonColors.primary, width: 3))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.item.icon,
                      color: isActive ? NeonColors.primary : NeonColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.item.label,
                        style: TextStyle(
                          color: isActive ? NeonColors.primary : NeonColors.textSecondary,
                          fontSize: 13,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isActive)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: NeonColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: NeonColors.primary.withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateur WebSocket avec animation de pulsation
class _WsIndicator extends StatefulWidget {
  final AdminWsStatus status;
  const _WsIndicator({required this.status});

  @override
  State<_WsIndicator> createState() => _WsIndicatorState();
}

class _WsIndicatorState extends State<_WsIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    if (widget.status == AdminWsStatus.connected) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.status) {
      AdminWsStatus.connected => NeonColors.success,
      AdminWsStatus.reconnecting => NeonColors.warning,
      _ => NeonColors.textMuted,
    };

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: widget.status == AdminWsStatus.connected
                ? 0.6 + (_pulse.value * 0.4)
                : 1.0,),
            shape: BoxShape.circle,
            boxShadow: widget.status == AdminWsStatus.connected
                ? [BoxShadow(color: color.withValues(alpha: _pulse.value * 0.4), blurRadius: 4, spreadRadius: 1)]
                : null,
          ),
        );
      },
    );
  }
}
