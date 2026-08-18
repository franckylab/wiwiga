// ============================================================
// Fichier: skeleton_loader.dart
// Description: Widgets skeleton loading pour les écrans admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';

/// Carte squelette pour le chargement
class AdminSkeletonCard extends StatefulWidget {
  final double height;
  final double? width;

  const AdminSkeletonCard({super.key, this.height = 80, this.width});

  @override
  State<AdminSkeletonCard> createState() => _AdminSkeletonCardState();
}

class _AdminSkeletonCardState extends State<AdminSkeletonCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: NeonColors.surface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ShaderMask(
              shaderCallback: (rect) {
                return LinearGradient(
                  colors: [
                    NeonColors.surface,
                    NeonColors.primary.withValues(alpha: 0.05),
                    NeonColors.surface,
                  ],
                  stops: [
                    (0.0 + _animation.value).clamp(0.0, 1.0),
                    (0.5 + _animation.value).clamp(0.0, 1.0),
                    (1.0 + _animation.value).clamp(0.0, 1.0),
                  ],
                ).createShader(rect);
              },
              blendMode: BlendMode.srcATop,
              child: Container(color: NeonColors.surface),
            ),
          ),
        );
      },
    );
  }
}

/// Liste squelette
class AdminSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const AdminSkeletonList({super.key, this.itemCount = 5, this.itemHeight = 72});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          itemCount,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AdminSkeletonCard(height: itemHeight),
          ),
        ),
      ),
    );
  }
}

/// Tableau squelette
class AdminSkeletonTable extends StatelessWidget {
  final int rowCount;
  final int columnCount;

  const AdminSkeletonTable({super.key, this.rowCount = 5, this.columnCount = 4});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Row(
            children: List.generate(columnCount, (i) => const Expanded(child: Padding(padding: EdgeInsets.all(8), child: AdminSkeletonCard(height: 24)))),
          ),
          const SizedBox(height: 8),
          // Rows
          ...List.generate(rowCount, (r) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(columnCount, (c) => const Expanded(child: Padding(padding: EdgeInsets.all(8), child: AdminSkeletonCard(height: 20)))),
            ),
          ),),
        ],
      ),
    );
  }
}
