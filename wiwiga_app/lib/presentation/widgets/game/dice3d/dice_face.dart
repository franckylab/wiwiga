// ============================================================
// Fichier: dice_face.dart
// Description: Face de dé validée + orientation 3D cible par face.
//              La face vient TOUJOURS du serveur Phoenix, jamais du client.
// Auteur: WIWIGA Team
// ============================================================

import 'package:vector_math/vector_math_64.dart';

/// Face de dé imposée par le serveur (1..6).
/// Pourquoi un objet dédié : un int nu laisse passer 0/7 (crash silencieux
/// ou face vide). Ici la validation est centralisée et testée.
class DiceFace {
  /// Valeur serveur, garantie 1..6.
  final int value;

  const DiceFace._(this.value);

  /// Construit depuis le payload serveur. Lève [ArgumentError] si invalide.
  /// Pourquoi lever ici : un payload corrompu ne doit jamais lancer l'anim.
  factory DiceFace.fromServer(int value) {
    if (!isValid(value)) {
      throw ArgumentError.value(value, 'face', 'doit être entre 1 et 6');
    }
    return DiceFace._(value);
  }

  /// Validation pure, réutilisée par le contrôleur et le service.
  static bool isValid(int value) => value >= 1 && value <= 6;

  @override
  String toString() => 'DiceFace($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiceFace && other.value == value);

  @override
  int get hashCode => value.hashCode;
}

/// Orientations cibles : quaternion qui amène [face] sur +Y (dessus)
/// avec 1 sur +Z (face caméra) au repos.
/// Pourquoi une table unique : V1 (Matrix4) et V2 (Filament) partagent
/// la même convention, le snap final est donc identique partout.
abstract class DiceFaceOrientation {
  static const double _deg2rad = 0.017453292519943295;

  static final Map<int, Quaternion> _cache = {};

  /// Retourne l'orientation cible (instance mise en cache, ne pas muter).
  static Quaternion forFace(int face) {
    assert(DiceFace.isValid(face), 'face 1..6');
    if (!DiceFace.isValid(face)) {
      throw ArgumentError.value(face, 'face', 'doit être entre 1 et 6');
    }
    return _cache.putIfAbsent(face, () => _build(face));
  }

  static Quaternion _build(int face) {
    switch (face) {
      case 1:
        return Quaternion.euler(0, 0, 0);
      case 6:
        return Quaternion.euler(180 * _deg2rad, 0, 0);
      case 2:
        return Quaternion.euler(-90 * _deg2rad, 0, 0);
      case 5:
        return Quaternion.euler(90 * _deg2rad, 0, 0);
      case 3:
        return Quaternion.euler(0, 0, 90 * _deg2rad);
      default: // 4
        return Quaternion.euler(0, 0, -90 * _deg2rad);
    }
  }
}
