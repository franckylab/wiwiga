// ============================================================
// Fichier: token_showcase_screen.dart
// Description: Showcase QA — toutes les variantes de pièces 3D
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/neon_theme.dart';
import '../../widgets/neon/neon_widgets.dart';

class TokenShowcaseScreen extends StatefulWidget {
  const TokenShowcaseScreen({super.key});

  @override
  State<TokenShowcaseScreen> createState() => _TokenShowcaseScreenState();
}

class _TokenShowcaseScreenState extends State<TokenShowcaseScreen> {
  double _size = 72;
  TokenMetal _metal = TokenMetal.emerald;
  TokenEffect _effect = TokenEffect.none;
  bool _withStack = false;
  int _stackCount = 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeonColors.background,
      appBar: AppBar(
        title: const Text(
          'Showcase Wiga 3D',
          style: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold),
        ),
        backgroundColor: NeonColors.surface,
        foregroundColor: NeonColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildControls(),
          const SizedBox(height: 20),
          _buildPreview(),
          const SizedBox(height: 24),
          _buildSizeMatrix(),
          const SizedBox(height: 24),
          _buildMetalMatrix(),
          const SizedBox(height: 24),
          _buildLodDemo(),
          const SizedBox(height: 24),
          _buildContextDemos(),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contrôles interactifs',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Taille',
                style: TextStyle(color: NeonColors.textSecondary, fontSize: 12),
              ),
              Expanded(
                child: Slider(
                  value: _size,
                  min: 16,
                  max: 160,
                  divisions: 18,
                  label: _size.round().toString(),
                  activeColor: NeonColors.primary,
                  onChanged: (v) => setState(() => _size = v),
                ),
              ),
              Text(
                '${_size.round()} px',
                style: const TextStyle(
                  color: NeonColors.primary,
                  fontFamily: 'Orbitron',
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TokenMetal.values.map((m) {
              final isSel = m == _metal;
              return ChoiceChip(
                label: Text(
                  m.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSel
                        ? NeonColors.background
                        : NeonColors.textSecondary,
                  ),
                ),
                selected: isSel,
                selectedColor: NeonColors.primary,
                onSelected: (_) => setState(() => _metal = m),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: TokenEffect.values.map((e) {
              final isSel = e == _effect;
              return ChoiceChip(
                label: Text(
                  e.name,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSel
                        ? NeonColors.background
                        : NeonColors.textSecondary,
                  ),
                ),
                selected: isSel,
                selectedColor: NeonColors.secondary,
                onSelected: (_) => setState(() => _effect = e),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _withStack,
                onChanged: (v) => setState(() => _withStack = v),
                activeThumbColor: NeonColors.primary,
              ),
              const Text(
                'Stack',
                style: TextStyle(color: NeonColors.textSecondary, fontSize: 12),
              ),
              if (_withStack) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _stackCount.toDouble(),
                    min: 1,
                    max: 7,
                    divisions: 6,
                    label: '$_stackCount',
                    activeColor: NeonColors.secondary,
                    onChanged: (v) => setState(() => _stackCount = v.round()),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return NeonCard(
      child: Column(
        children: [
          Text(
            'Aperçu — ${_metal.name} • ${_size.round()} px • ${_effect.name}',
            style:
                const TextStyle(color: NeonColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Center(
            child: _withStack
                ? TokenStack(
                    count: _stackCount,
                    size: _size.clamp(24, 64),
                    metal: _metal,
                    altMetal: _metal == TokenMetal.gold
                        ? TokenMetal.emerald
                        : TokenMetal.gold,
                  )
                : TokenCoin(
                    size: _size,
                    metal: _metal,
                    lod: TokenCoin.autoLod(_size),
                    effect: _effect,
                    animated: _effect != TokenEffect.none,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'LOD: ${TokenCoin.autoLod(_size).name}',
            style: const TextStyle(
              color: NeonColors.textMuted,
              fontSize: 11,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeMatrix() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Matrice tailles — LOD auto',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [16, 24, 36, 44, 72, 96, 120, 160].map((s) {
              final d = s.toDouble();
              return Column(
                children: [
                  TokenCoin(
                    size: d,
                    metal: TokenMetal.emerald,
                    lod: TokenCoin.autoLod(d),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$s px',
                    style: const TextStyle(
                      color: NeonColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    TokenCoin.autoLod(d).name,
                    style: const TextStyle(
                      color: NeonColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetalMatrix() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Métaux — 6 variantes',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: TokenMetal.values.map((m) {
              return Column(
                children: [
                  TokenCoin(
                    size: 56,
                    metal: m,
                    lod: TokenLod.full,
                    effect: m == TokenMetal.holographic
                        ? TokenEffect.shimmer
                        : TokenEffect.none,
                    animated: m == TokenMetal.holographic,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.name,
                    style: const TextStyle(
                      color: NeonColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            children: [
              TokenCoin(
                size: 40,
                metal: TokenMetal.gold,
                lod: TokenLod.full,
                rankLabel: '1',
                withW: false,
              ),
              TokenCoin(
                size: 40,
                metal: TokenMetal.silver,
                lod: TokenLod.full,
                rankLabel: '2',
                withW: false,
              ),
              TokenCoin(
                size: 40,
                metal: TokenMetal.bronze,
                lod: TokenLod.full,
                rankLabel: '3',
                withW: false,
              ),
              TokenCoin(
                size: 40,
                metal: TokenMetal.diamond,
                lod: TokenLod.full,
                rankLabel: 'D',
                withW: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLodDemo() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LOD — flat → full (même métal, tailles différentes)',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _lodItem('flat', TokenLod.flat, 20),
              _lodItem('bevel', TokenLod.bevel, 32),
              _lodItem('edge', TokenLod.edge, 48),
              _lodItem('full', TokenLod.full, 72),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lodItem(String label, TokenLod lod, double size) {
    return Column(
      children: [
        TokenCoin(size: size, metal: TokenMetal.emerald, lod: lod),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: NeonColors.textMuted, fontSize: 10),
        ),
        Text(
          '${size.toInt()} px',
          style: const TextStyle(color: NeonColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildContextDemos() {
    return NeonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contextes — presets recommandés',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _contextRow(
            'Header solde',
            const TokenCoin(
              size: 28,
              metal: TokenMetal.emerald,
              effect: TokenEffect.pulse,
              animated: true,
            ),
            '22–28 px • bevel • pulse',
          ),
          _contextRow(
            'Hero wallet',
            const TokenCoin(
              size: 44,
              metal: TokenMetal.gold,
              effect: TokenEffect.shimmer,
              animated: true,
            ),
            '42–72 px • full • shimmer',
          ),
          _contextRow(
            'Chips mises',
            const TokenChip(amount: 100, isSelected: true, size: 40),
            '40 px • edge • flip',
          ),
          _contextRow(
            'Pot',
            const TokenStack(
              count: 5,
              size: 32,
              metal: TokenMetal.emerald,
              altMetal: TokenMetal.gold,
            ),
            '32×5 • full • float',
          ),
          _contextRow(
            'Victoire',
            const TokenCoin(
              size: 72,
              metal: TokenMetal.gold,
              effect: TokenEffect.spin,
              animated: true,
            ),
            '120 px • full • spin',
          ),
          _contextRow(
            'Podium #1',
            const TokenCoin(
              size: 48,
              metal: TokenMetal.gold,
              rankLabel: '1',
              withW: false,
              effect: TokenEffect.shimmer,
              animated: true,
            ),
            '48 px • full • shimmer',
          ),
          _contextRow(
            'Inline 14',
            const TokenCoin(
              size: 14,
              metal: TokenMetal.emerald,
              lod: TokenLod.flat,
              showShadow: false,
            ),
            '14 px • flat • none',
          ),
        ],
      ),
    );
  }

  Widget _contextRow(String label, Widget coin, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: NeonColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ),
          coin,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(
                color: NeonColors.textMuted,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
