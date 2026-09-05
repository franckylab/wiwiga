// ============================================================
// Fichier: currency.dart
// Description: Constantes et helpers monnaie WIWIGA — wiga
//   1 wiga = 1 FCFA (taux 1:1), affichage centralisé
// Auteur: WIWIGA Team
// Date: 2026-08-30
// ============================================================

import 'package:intl/intl.dart';

/// Label monnaie interne WIWIGA — invariant (1 wiga, 50 wiga)
const String kWigaLabel = 'wiga';
const String kWigaLabelUpper = 'WIGA';
const String kWigaLabelPlural = 'wiga'; // invariant, évite wigas

/// Formateur milliers FR (espace fine) — fallback si locale non dispo
final NumberFormat _wigaFormat = (() {
  try {
    return NumberFormat('#,##0', 'fr_FR');
  } catch (_) {
    return NumberFormat.decimalPattern();
  }
})();

/// Formate un montant en wiga (ex: 12345 → "12 345 wiga")
String formatWiga(int amount, {bool withLabel = true}) {
  final n = _wigaFormat.format(amount);
  return withLabel ? '$n $kWigaLabel' : n;
}

/// Variante sans label pour composition Row(Text, TokenCoin)
String formatWigaAmount(int amount) => _wigaFormat.format(amount);

/// Alias rétro-compat wiga → wiga
@Deprecated('Utiliser formatWiga')
String formatTokens(int amount) => formatWiga(amount);
