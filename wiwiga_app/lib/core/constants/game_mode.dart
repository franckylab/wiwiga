// ============================================================
// Fichier: game_mode.dart
// Description: Référentiel modes WIWIGA — migration brutale 2026-08-30
//              SUPPRIME "Mise en ligne"/"betting"/"pari" — uniquement free/staked
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-08-30
// ============================================================

/// Modes canoniques WIWIGA — seuls valides depuis 2026-08-30.
///
/// - [free]   → Partie sans mise (gratuit)
/// - [staked] → Partie avec mise
enum GameMode {
  free,
  staked;

  /// Parse strict. Seuls free/staked et variantes françaises sans_mise/avec_mise acceptés.
  /// Lève [ArgumentError] si invalide — pas de fallback betting.
  static GameMode parse(String? raw) {
    if (raw == null) throw ArgumentError('mode requis: free | staked');
    final v = raw.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    const freeAliases = {'free', 'sans_mise', 'without_stake', 'gratuit'};
    const stakedAliases = {'staked', 'avec_mise', 'with_stake'};
    if (freeAliases.contains(v)) return GameMode.free;
    if (stakedAliases.contains(v)) return GameMode.staked;
    if (v == 'free') return GameMode.free;
    if (v == 'staked') return GameMode.staked;
    throw ArgumentError('mode invalide: $raw — attendu free | staked');
  }

  /// Parse souple retournant null si invalide.
  static GameMode? tryParse(String? raw) {
    try {
      return parse(raw);
    } catch (_) {
      return null;
    }
  }

  String get apiValue {
    switch (this) {
      case GameMode.free:
        return 'free';
      case GameMode.staked:
        return 'staked';
    }
  }

  String get displayLabel {
    switch (this) {
      case GameMode.free:
        return 'Partie sans mise (gratuit)';
      case GameMode.staked:
        return 'Partie avec mise';
    }
  }

  String get shortLabel {
    switch (this) {
      case GameMode.free:
        return 'Sans mise';
      case GameMode.staked:
        return 'Avec mise';
    }
  }

  String get subtitle {
    switch (this) {
      case GameMode.free:
        return 'Gratuit • Entre amis';
      case GameMode.staked:
        return 'Jetons en jeu';
    }
  }

  String get description {
    switch (this) {
      case GameMode.free:
        return 'Partie amicale sans enjeu — idéale pour jouer entre amis.';
      case GameMode.staked:
        return 'Partie avec mise en jetons — gains réels après commission.';
    }
  }

  bool get isFree => this == GameMode.free;
  bool get isStaked => this == GameMode.staked;
}

class GameModes {
  static const String freeLabel = 'Partie sans mise (gratuit)';
  static const String stakedLabel = 'Partie avec mise';
  static const String freeShort = 'Sans mise';
  static const String stakedShort = 'Avec mise';

  static String normalize(String? raw) => GameMode.parse(raw).apiValue;
  static String labelOf(String? raw) => GameMode.parse(raw).displayLabel;
  static String shortLabelOf(String? raw) => GameMode.parse(raw).shortLabel;
  static bool isStaked(String? raw) => GameMode.parse(raw).isStaked;
  static bool isFree(String? raw) => GameMode.parse(raw).isFree;
}
