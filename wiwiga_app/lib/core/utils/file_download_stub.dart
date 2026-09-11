// ============================================================
// Fichier: file_download_stub.dart (mobile/desktop : temp + chemin)
// ============================================================

import 'dart:convert';
import 'dart:io';

/// Écrit [content] dans le dossier temporaire et retourne le chemin.
/// L'admin peut ensuite le récupérer (partage système hors scope).
Future<String> downloadTextFile(String filename, String content) async {
  final file = File('${Directory.systemTemp.path}/$filename');
  await file.writeAsString(content, encoding: utf8);
  return file.path;
}
