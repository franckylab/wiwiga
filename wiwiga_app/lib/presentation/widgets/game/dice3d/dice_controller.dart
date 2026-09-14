// ============================================================
// Fichier: dice_controller.dart
// Description: Propriétaire unique de l'état "lancer en cours".
//              Anti double-clic + anti rejeu (roll_id) + validation face.
//              Distingue tumbling provisoire (résultat pas encore connu)
//              et cible serveur confirmée : JAMAIS de face fabriquée.
// Auteur: WIWIGA Team
// ============================================================

import 'package:flutter/foundation.dart';

import 'dice_face.dart';

/// Contrôleur impératif du dé 3D.
///
/// Deux usages :
/// ```dart
/// // Cas simple : résultat serveur déjà connu.
/// controller.roll(faceServeur, rollId: rollIdServeur);
///
/// // Match temps réel : tumbling immédiat, cible à l'arrivée du résultat.
/// controller.beginTumble(rollId: rollIdTap); // sur `dice_rolling`
/// controller.retarget(faceServeur);         // sur `dice_rolled`
/// ```
/// Le widget [Dice3D] écoute ce contrôleur et joue l'animation.
/// [notifySettled] est appelé par le widget en fin d'animation.
class Dice3DController extends ChangeNotifier {
  bool _isRolling = false;

  /// Face cible (null pendant le tumbling provisoire).
  int? _face;

  /// Vrai dès que la cible vient du serveur (roll ou retarget).
  /// Faux = tumbling provisoire : le widget ne doit JAMAIS se figer dessus.
  bool _confirmed = false;
  String? _rollId;

  /// Face affichée au repos (0 = vide). Mise à jour sans animation,
  /// depuis l'état serveur (polling REST, historique) — jamais un résultat.
  int _restingFace = 0;
  final Set<String> _seenRollIds = {};

  /// Vrai pendant l'animation (bouton "Lancer" doit être désactivé).
  bool get isRolling => _isRolling;

  /// Face serveur en cours d'animation (null si tumbling provisoire).
  int? get face => _face;

  /// Vrai si la cible est confirmée serveur (figeage autorisé en fin d'anim).
  bool get hasServerTarget => _confirmed;

  /// Identifiant idempotent du lancer en cours (null au repos initial).
  String? get rollId => _rollId;

  /// Face de repos (0 = vide). Le widget l'affiche sans animation.
  int get restingFace => _restingFace;

  /// Déclenche l'animation vers [face] (valeur SERVEUR uniquement).
  ///
  /// Retourne false (sans effet) si :
  /// - un lancer est déjà en cours (anti double-clic),
  /// - [face] hors 1..6,
  /// - [rollId] vide ou déjà vu (anti rejeu).
  bool roll(int face, {required String rollId}) {
    // Valide la face AVANT le tumbling : sinon une face invalide laisserait
    // le contrôleur bloqué en tumbling sans cible (test l'a prouvé).
    if (!DiceFace.isValid(face)) return false;
    if (!beginTumble(rollId: rollId)) return false;
    retarget(face);
    return true;
  }

  /// Démarre le tumbling SANS cible (résultat serveur pas encore connu).
  /// Le widget tourne en boucle jusqu'au [retarget] : aucune face affichée
  /// au repos ne peut provenir d'ici (pas de résultat fabriqué).
  /// Mêmes gardes anti double-clic / anti rejeu que [roll].
  bool beginTumble({required String rollId}) {
    if (_isRolling) return false;
    if (rollId.isEmpty || _seenRollIds.contains(rollId)) return false;
    _isRolling = true;
    _face = null;
    _confirmed = false;
    _rollId = rollId;
    _seenRollIds.add(rollId);
    // Borne mémoire : 200 derniers roll_id suffisent (match < 50 sets).
    if (_seenRollIds.length > 200) {
      _seenRollIds.remove(_seenRollIds.first);
    }
    notifyListeners();
    return true;
  }

  /// Relance le tumbling pour un NOUVEAU lancer même si une animation est
  /// déjà en cours (tours rapides consécutifs : J1 puis J2 < 1,6 s).
  /// Pourquoi : sans ça, le `beginTumble` du joueur suivant est rejeté
  /// (`isRolling` encore vrai) → aucune animation visible, le résultat
  /// s'affiche directement. Ici on garde `_isRolling` vrai (pas de flash
  /// au repos) mais on change de `rollId` et on efface la cible précédente :
  /// le widget continue son tumbling vers la nouvelle cible serveur.
  /// Retourne false si [rollId] vide ou déjà vu (anti rejeu conservé).
  bool restartTumble({required String rollId}) {
    if (rollId.isEmpty || _seenRollIds.contains(rollId)) return false;
    _isRolling = true;
    _face = null;
    _confirmed = false;
    _rollId = rollId;
    _seenRollIds.add(rollId);
    if (_seenRollIds.length > 200) {
      _seenRollIds.remove(_seenRollIds.first);
    }
    notifyListeners();
    return true;
  }

  /// Confirme la face SERVEUR pendant l'animation (`dice_rolled` arrivé
  /// après `dice_rolling`). Le blend final utilisera cette face : garantie
  /// face serveur préservée. Retourne false si pas en cours ou invalide.
  bool retarget(int face) {
    if (!_isRolling) return false;
    if (!DiceFace.isValid(face)) return false;
    if (_face == face && _confirmed) return true;
    _face = face;
    _confirmed = true;
    notifyListeners();
    return true;
  }

  /// Affiche [face] au repos SANS animation (0 = vide).
  /// Pourquoi : synchronisation REST/polling et historique — le dé doit
  /// refléter l'état serveur même sans event (pas d'anim fantôme).
  void setRestingFace(int face) {
    if (face < 0 || face > 6) return;
    if (_isRolling) {
      // En cours d'anim : mémorise pour la fin (corrige toute dérive).
      _restingFace = face;
      return;
    }
    if (_restingFace == face) return;
    _restingFace = face;
    notifyListeners();
  }

  /// Signale la fin d'animation (appelé par le widget, pas par l'écran).
  /// Sans cible confirmée, le widget ne doit pas appeler ceci (il boucle).
  void notifySettled() {
    if (!_isRolling) return;
    _isRolling = false;
    _restingFace = _face ?? _restingFace;
    notifyListeners();
  }

  /// Réinitialise au repos (ex : nouveau set, sortie d'écran).
  /// Le widget annule toute animation en cours via ce signal.
  void reset() {
    _isRolling = false;
    _face = null;
    _confirmed = false;
    _rollId = null;
    _restingFace = 0;
    notifyListeners();
  }
}
