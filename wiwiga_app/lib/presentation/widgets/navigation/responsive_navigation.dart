import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/theme/typography.dart';

/// Navigation responsive qui s'adapte selon la taille de l'écran
/// 
/// Mobile (< 600px) : Bottom Navigation Bar
/// Tablet (600-1024px) : Navigation Rail
/// Desktop (> 1024px) : Sidebar Navigation
/// 
/// Suit les 17 breakpoints de rl_responsive-design.md
class ResponsiveNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onDestinationSelected;
  final List<NavDestination> destinations;
  final Widget body;
  final Widget? floatingActionButton;
  final String? appBarTitle;
  final List<Widget>? appBarActions;

  const ResponsiveNavigation({
    Key? key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.floatingActionButton,
    this.appBarTitle,
    this.appBarActions,
  }) : super(key: key);

  @override
  State<ResponsiveNavigation> createState() => _ResponsiveNavigationState();
}

class _ResponsiveNavigationState extends State<ResponsiveNavigation> {
  bool _isDrawerOpen = false;

  NavigationLayoutType _getLayoutType(double width) {
    if (width < 600) {
      return NavigationLayoutType.bottomNav;
    } else if (width < 1024) {
      return NavigationLayoutType.navigationRail;
    } else {
      return NavigationLayoutType.sidebar;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layoutType = _getLayoutType(constraints.maxWidth);

        switch (layoutType) {
          case NavigationLayoutType.bottomNav:
            return _buildBottomNavigation();
          case NavigationLayoutType.navigationRail:
            return _buildNavigationRail();
          case NavigationLayoutType.sidebar:
            return _buildSidebarNavigation();
        }
      },
    );
  }

  /// Mobile : Bottom Navigation Bar
  Widget _buildBottomNavigation() {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.appBarTitle ?? 'WIWIGA',
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NeonColors.background,
        actions: widget.appBarActions ?? [],
      ),
      body: widget.body,
      floatingActionButton: widget.floatingActionButton,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: NeonColors.surface,
          border: Border(
            top: BorderSide(
              color: NeonColors.primary,
              width: NeonGlow.borderWidth,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: NeonColors.primary.withOpacity(NeonGlow.opacityLow),
              blurRadius: NeonGlow.blurSmall,
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: NeonColors.primary.withOpacity(0.2),
          selectedIndex: widget.currentIndex,
          onDestinationSelected: widget.onDestinationSelected,
          destinations: widget.destinations.map((dest) {
            return NavigationDestination(
              icon: Icon(dest.icon, color: NeonColors.textSecondary),
              selectedIcon: Icon(dest.icon, color: NeonColors.primary),
              label: dest.label,
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Tablet : Navigation Rail
  Widget _buildNavigationRail() {
    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: NeonColors.surface,
              border: Border(
                right: BorderSide(
                  color: NeonColors.primary,
                  width: NeonGlow.borderWidth,
                ),
              ),
            ),
            child: NavigationRail(
              backgroundColor: Colors.transparent,
              selectedIndex: widget.currentIndex,
              onDestinationSelected: widget.onDestinationSelected,
              extended: false,
              destinations: widget.destinations.map((dest) {
                return NavigationRailDestination(
                  icon: Icon(dest.icon, color: NeonColors.textSecondary),
                  selectedIcon: Icon(dest.icon, color: NeonColors.primary),
                  label: Text(
                    dest.label,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
              selectedLabelTextStyle: TextStyle(
                color: NeonColors.primary,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: NeonColors.textSecondary,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                _buildRailAppBar(),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildRailAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: NeonColors.background,
        border: Border(
          bottom: BorderSide(color: NeonColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.appBarTitle ?? 'WIWIGA',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: NeonColors.primary,
            ),
          ),
          if (widget.appBarActions != null)
            Row(children: widget.appBarActions!),
        ],
      ),
    );
  }

  /// Desktop : Sidebar Navigation
  Widget _buildSidebarNavigation() {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildDesktopAppBar(),
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: NeonColors.surface,
        border: Border(
          right: BorderSide(
            color: NeonColors.primary,
            width: NeonGlow.borderWidth,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: NeonColors.primary.withOpacity(NeonGlow.opacityLow),
            blurRadius: NeonGlow.blurMedium,
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo
          _buildSidebarHeader(),
          
          const SizedBox(height: 24),
          
          // Navigation Items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: widget.destinations.length,
              itemBuilder: (context, index) {
                final dest = widget.destinations[index];
                final isSelected = widget.currentIndex == index;
                
                return _SidebarItem(
                  icon: dest.icon,
                  label: dest.label,
                  isSelected: isSelected,
                  onTap: () => widget.onDestinationSelected(index),
                );
              },
            ),
          ),
          
          // Footer
          _buildSidebarFooter(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: NeonGradients.cta,
              boxShadow: [
                BoxShadow(
                  color: NeonColors.primary.withOpacity(NeonGlow.opacityMedium),
                  blurRadius: NeonGlow.blurSmall,
                ),
              ],
            ),
            child: Icon(
              Icons.gamepad,
              color: NeonColors.background,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'WIWIGA',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: NeonColors.primary,
              fontFamily: 'Orbitron',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: NeonColors.border),
        ),
      ),
      child: Column(
        children: [
          Text(
            'v1.0.0',
            style: TextStyle(
              color: NeonColors.textSecondary.withOpacity(0.5),
              fontSize: 12,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: NeonColors.background,
        border: Border(
          bottom: BorderSide(color: NeonColors.border),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.appBarTitle ?? 'WIWIGA',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: NeonColors.primary,
            ),
          ),
          if (widget.appBarActions != null)
            Row(children: widget.appBarActions!),
        ],
      ),
    );
  }
}

enum NavigationLayoutType {
  bottomNav,
  navigationRail,
  sidebar,
}

class NavDestination {
  final IconData icon;
  final String label;

  const NavDestination({
    required this.icon,
    required this.label,
  });
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: NeonAnimations.standard,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? NeonColors.primary.withOpacity(0.2)
              : _isHovered
                  ? NeonColors.primary.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
          border: widget.isSelected
              ? Border.all(
                  color: NeonColors.primary,
                  width: NeonGlow.borderWidth,
                )
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(NeonTheme.borderRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: widget.isSelected
                        ? NeonColors.primary
                        : NeonColors.textSecondary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: widget.isSelected
                          ? NeonColors.primary
                          : NeonColors.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
