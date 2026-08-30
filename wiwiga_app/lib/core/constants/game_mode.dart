// ============================================================
// Fichier: game_mode.dart
// Description: Référentiel centralisé des modes de jeu WIWIGA
//              Remplace "Mise en ligne" par Partie sans/avec mise
// Auteur: Franck Arlos CHENDJOU
// Date: 2026-08-30
// ============================================================

/// Modes de jeu canoniques WIWIGA.
///
/// - [free]   → Partie sans mise (gratuit) — amical, sans enjeu.
/// - [staked] → Partie avec mise — avec enjeu en jetons.
///
/// L'ancien identifiant `"betting"` est conservé comme **alias** de [staked]
/// pour rétro-compatibilité (backend < 2026-08-30).
enum GameMode {
  free,
  staked;

  /// Parse une valeur brute (string nullable) vers le mode canonique.
  /// Normalise automatiquement `"betting"` → [staked].
  static GameMode parse(String? raw) {
    if (raw == null) return GameMode.free;
    final v = raw.trim().toLowerCase().replaceAll(' ', '_').replaceAll('-', '_');
    const freeAliases = {'free', 'sans_mise', 'without_stake', 'gratuit', 'sans_mise_gratuit'};
    const stakedAliases = {
      'staked',
      'betting',
      'avec_mise',
      'with_stake',
      'pari',
      'mise',
      'mise_en_ligne',
      'avec_mise_payante',
    };
    if (freeAliases.contains(v)) return GameMode.free;
    if (stakedAliases.contains(v)) return GameMode.staked;
    // Par défaut : si valeur inconnue, considérer comme free pour sécurité
    if (v == 'staked') return GameMode.staked;
    if (v == 'free') return GameMode.free;
    return GameMode.free;
  }

  /// Valeur sérialisée pour l'API (canonique : "free" | "staked").
  String get apiValue {
    switch (this) {
      case GameMode.free:
        return 'free';
      case GameMode.staked:
        return 'staked';
    }
  }

  /// Alias historique : l'API ancienne attendait "betting".
  /// Ne plus utiliser pour l'envoi, seulement pour compat lecture.
  String get legacyApiValue {
    switch (this) {
      case GameMode.free:
        return 'free';
      case GameMode.staked:
        return 'betting';
    }
  }

  /// Label complet français pour UI.
  String get displayLabel {
    switch (this) {
      case GameMode.free:
        return 'Partie sans mise (gratuit)';
      case GameMode.staked:
        return 'Partie avec mise';
    }
  }

  /// Label court français.
  String get shortLabel {
    switch (this) {
      case GameMode.free:
        return 'Sans mise';
      case GameMode.staked:
        return 'Avec mise';
    }
  }

  /// Sous-titre explicatif.
  String get subtitle {
    switch (this) {
      case GameMode.free:
        return 'Gratuit • Entre amis';
      case GameMode.staked:
        return 'Jetons en jeu';
    }
  }

  /// Description longue.
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

  /// Alias déprécié conservé pour compatibilité code existant.
  bool get isBetting => isStaked;
}

/// Helpers statiques legacy (si code utilise strings directement).
class GameModes {
  static const String freeLabel = 'Partie sans mise (gratuit)';
  static const String stakedLabel = 'Partie avec mise';
  static const String freeShort = 'Sans mise';
  static const String stakedShort = 'Avec mise';

  /// Normalise une string mode vers sa valeur canonique API.
  static String normalize(String? raw) => GameMode.parse(raw).apiValue;

  /// Retourne le label complet depuis une string brute.
  static String labelOf(String? raw) => GameMode.parse(raw).displayLabel;

  /// Retourne le label court depuis une string brute.
  static String shortLabelOf(String? raw) => GameMode.parse(raw).shortLabel;

  /// Vérifie si une string correspond à un mode avec mise.
  static bool isStaked(String? raw) => GameMode.parse(raw).isStaked;
  static bool isFree(String? raw) => GameMode.parse(raw).isFree;

  /// Alias déprécié.
  static bool isBetting(String? raw) => isStaked(raw);
}
