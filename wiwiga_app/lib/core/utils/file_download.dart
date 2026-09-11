// ============================================================
// Fichier: file_download.dart
// Description: Téléchargement de fichier (web = navigateur,
//              mobile/desktop = dossier temporaire), via imports
//              conditionnels (dart:html indisponible hors web).
// ============================================================

export 'file_download_stub.dart' if (dart.library.html) 'file_download_web.dart';
