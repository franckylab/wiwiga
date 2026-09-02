// ============================================================
// Fichier: gift_sheet.dart
// Description: BottomSheet cadeau wiga entre amis uniquement
// Auteur: WIWIGA Team — Refonte 2026-08-31
// Best-practices: picker ami, confirmation, frais visibles, limites
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../core/errors/error_handler.dart';
import '../../../core/widgets/wiwiga_error_view.dart';
import '../../widgets/neon/neon_widgets.dart';
import '../../../data/models/friend_model.dart';
import '../../../data/providers/token_provider.dart';
import '../../providers/config_provider.dart';

/// Affiche le GiftSheet pour un ami donné. Retourne true si envoi réussi.
Future<bool?> showGiftSheet(BuildContext context, FriendModel friend) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: NeonColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => GiftSheet(friend: friend),
  );
}

class GiftSheet extends ConsumerStatefulWidget {
  final FriendModel friend;
  const GiftSheet({super.key, required this.friend});

  @override
  ConsumerState<GiftSheet> createState() => _GiftSheetState();
}

class _GiftSheetState extends ConsumerState<GiftSheet> {
  final _amountCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _selectedAmount = 0;
  bool _sending = false;

  static const _quickAmounts = [50, 100, 200, 500, 1000, 2000];
  static const _maxMessageLen = 140;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenState = ref.watch(tokenProvider);
    final tokensConfigAsync = ref.watch(tokensConfigProvider);
    final balance = tokenState.tokenBalance;

    final giftFeePercent = tokensConfigAsync.when(
      data: (c) => c.giftFeePercent,
      loading: () => 5.0,
      error: (_, __) => 5.0,
    );
    final dailyGiftLimit = tokensConfigAsync.when(
      data: (c) => c.dailyGiftLimit,
      loading: () => 10000,
      error: (_, __) => 10000,
    );

    // Frais et aperçu : pour l'instant frais informatifs (backend ne prélève pas encore)
    // affichage : vous envoyez X, receveur reçoit X, frais 0 si giftFee inclus coté plateforme
    final isValid = _selectedAmount > 0 && _selectedAmount <= balance;
    final afterBalance = balance - _selectedAmount;
    final feePreview = (_selectedAmount * giftFeePercent / 100).round();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NeonColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Header ami
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: widget.friend.isOnline
                          ? NeonColors.success.withValues(alpha: 0.2)
                          : NeonColors.surface,
                      child: Text(
                        widget.friend.name.isNotEmpty
                            ? widget.friend.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: NeonColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    if (widget.friend.isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: NeonColors.success,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: NeonColors.surface, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offrir à ${widget.friend.name}',
                        style: const TextStyle(
                          color: NeonColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.friend.isInGame
                            ? 'En partie'
                            : (widget.friend.isOnline
                                ? 'En ligne'
                                : 'Hors ligne'),
                        style: TextStyle(
                          color: widget.friend.isInGame
                              ? NeonColors.warning
                              : (widget.friend.isOnline
                                  ? NeonColors.success
                                  : NeonColors.textSecondary),
                          fontSize: 12,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const TokenCoin(
                  size: 28,
                  metal: TokenMetal.gold,
                  lod: TokenLod.bevel,
                  showShadow: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Info limites & frais
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Solde disponible',
                          style: TextStyle(
                            color: NeonColors.textSecondary,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              _fmt(balance),
                              style: const TextStyle(
                                color: NeonColors.success,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'wiga',
                              style: TextStyle(
                                color: NeonColors.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Limite cadeau / jour',
                          style: TextStyle(
                            color: NeonColors.textSecondary,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '${_fmt(dailyGiftLimit)} wiga',
                          style: const TextStyle(
                            color: NeonColors.primary,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (giftFeePercent > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Frais cadeau',
                            style: TextStyle(
                              color: NeonColors.textSecondary,
                              fontFamily: 'Inter',
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${giftFeePercent.toStringAsFixed(1)} %  •  ~${_fmt(feePreview)} wiga',
                            style: const TextStyle(
                              color: NeonColors.textSecondary,
                              fontFamily: 'Inter',
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Montant
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MONTANT EN WIGA',
                      style: TextStyle(
                        color: NeonColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    NeonInput(
                      label: 'Nombre de wiga',
                      hint: 'Ex: 100',
                      keyboardType: TextInputType.number,
                      icon: Icons.monetization_on,
                      controller: _amountCtrl,
                      onChanged: (v) => setState(
                        () => _selectedAmount = int.tryParse(v) ?? 0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _quickAmounts
                          .map(
                            (a) => _QuickAmountButton(
                              amount: a,
                              isSelected: _selectedAmount == a,
                              onTap: () {
                                _amountCtrl.text = a.toString();
                                setState(() => _selectedAmount = a);
                              },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedAmount > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: NeonColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: NeonColors.border),
                        ),
                        child: Row(
                          children: [
                            const TokenCoin(
                              size: 20,
                              metal: TokenMetal.emerald,
                              lod: TokenLod.flat,
                              showShadow: false,
                              withW: true,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Après envoi :',
                              style: TextStyle(
                                color: NeonColors.textSecondary,
                                fontFamily: 'Inter',
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_fmt(afterBalance)} wiga',
                              style: TextStyle(
                                color: afterBalance < 0
                                    ? NeonColors.error
                                    : NeonColors.textPrimary,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedAmount > balance)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Solde insuffisant',
                          style: TextStyle(
                            color: NeonColors.error,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Message
            NeonCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MESSAGE (OPTIONNEL)',
                      style: TextStyle(
                        color: NeonColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    NeonInput(
                      label: 'Message',
                      hint: 'Joyeux anniversaire !',
                      icon: Icons.message_outlined,
                      controller: _messageCtrl,
                      maxLines: 2,
                      maxLength: _maxMessageLen,
                      onChanged: (_) => setState(() {}),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_messageCtrl.text.length}/$_maxMessageLen',
                        style: TextStyle(
                          color: _messageCtrl.text.length > _maxMessageLen
                              ? NeonColors.error
                              : NeonColors.textSecondary,
                          fontSize: 11,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Rappel amis uniquement
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NeonColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: NeonColors.info.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: NeonColors.info),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Les cadeaux sont réservés à tes amis. Pense à entretenir ton réseau !',
                      style: TextStyle(
                        color: NeonColors.textSecondary,
                        fontFamily: 'Inter',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // CTA + Annuler
            NeonButton(
              text: _sending ? 'ENVOI EN COURS...' : 'ENVOYER LE CADEAU',
              icon: _sending ? Icons.hourglass_top : Icons.card_giftcard,
              variant: NeonButtonVariant.success,
              width: double.infinity,
              isEnabled: isValid && !_sending && tokenState.giftEnabled,
              onPressed:
                  isValid && !_sending ? () => _sendGift(context) : () {},
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed:
                  _sending ? null : () => Navigator.of(context).pop(false),
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: NeonColors.textSecondary,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            if (!tokenState.giftEnabled)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: NeonColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.block, size: 16, color: NeonColors.error),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Les cadeaux sont temporairement désactivés par l’administration.',
                        style: TextStyle(
                          color: NeonColors.error,
                          fontFamily: 'Inter',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]} ',
      );

  Future<void> _sendGift(BuildContext context) async {
    final amount = _selectedAmount;
    final msg = _messageCtrl.text.trim();
    if (amount <= 0) return;

    // Confirmation si gros montant (>500 wiga)
    if (amount >= 500) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: NeonColors.surface,
          title: const Text(
            'Confirmer le cadeau',
            style: TextStyle(
              color: NeonColors.textPrimary,
              fontFamily: 'Orbitron',
            ),
          ),
          content: Text(
            'Envoyer ${_fmt(amount)} wiga à ${widget.friend.name} ?\n\nSolde après : ${_fmt(ref.read(tokenProvider).tokenBalance - amount)} wiga',
            style: const TextStyle(
              color: NeonColors.textSecondary,
              fontFamily: 'Inter',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Annuler',
                style: TextStyle(color: NeonColors.textSecondary),
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: NeonColors.success),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirmer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _sending = true);
    try {
      await ref
          .read(tokenProvider.notifier)
          .sendGift(widget.friend.id.toString(), amount, message: msg);
      final after = ref.read(tokenProvider);
      if (!context.mounted) return;
      if (after.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(after.error!),
            backgroundColor: NeonColors.error,
          ),
        );
        setState(() => _sending = false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cadeau de ${_fmt(amount)} wiga envoyé à ${widget.friend.name} !',
          ),
          backgroundColor: NeonColors.success,
        ),
      );
      if (context.mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      ErrorHandler.logError(e, st, context: 'GiftSheet.send');
      if (context.mounted) WiwigaSnack.showError(context, e);
      setState(() => _sending = false);
    }
  }
}

class _QuickAmountButton extends StatelessWidget {
  final int amount;
  final bool isSelected;
  final VoidCallback onTap;
  const _QuickAmountButton({
    required this.amount,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? NeonColors.primary.withValues(alpha: 0.2)
              : NeonColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? NeonColors.primary : NeonColors.border,
          ),
        ),
        child: Text(
          amount.toString().replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (m) => '${m[1]} ',
              ),
          style: TextStyle(
            color: isSelected ? NeonColors.primary : NeonColors.textPrimary,
            fontFamily: 'Orbitron',
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
