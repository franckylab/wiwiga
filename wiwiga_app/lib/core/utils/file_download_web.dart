// ============================================================
// Fichier: file_download_web.dart (implémentation web uniquement)
// ============================================================

import 'dart:convert';
import 'dart:html' as html;

/// Télécharge [content] comme [filename] via un blob navigateur.
/// Retourne le nom du fichier.
Future<String> downloadTextFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return filename;
}
