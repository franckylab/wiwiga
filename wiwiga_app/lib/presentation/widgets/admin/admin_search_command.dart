// ============================================================
// Fichier: admin_search_command.dart
// Description: Command palette (Ctrl+K) pour recherche globale admin
// Auteur: WIWIGA Team
// Date: 2026-08-25
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/neon_theme.dart';
import '../../../data/providers/app_providers.dart';

/// Command palette pour recherche globale admin
class AdminSearchCommand extends ConsumerStatefulWidget {
  const AdminSearchCommand({super.key});

  @override
  ConsumerState<AdminSearchCommand> createState() => _AdminSearchCommandState();
}

class _AdminSearchCommandState extends ConsumerState<AdminSearchCommand> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      // Chercher dans les utilisateurs
      final usersResult = await repo.listUsers(search: query, pageSize: 5);
      final users = (usersResult['users'] as List).map((u) {
        final user = u as Map<String, dynamic>;
        return {
          'type': 'user',
          'title': user['name'] ?? user['phone'] ?? 'Utilisateur',
          'subtitle': user['phone'] ?? '',
          'route': '/admin/users',
          'icon': Icons.person,
        };
      }).toList();

      setState(() {
        _results = users.cast<Map<String, dynamic>>();
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: NeonColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: NeonColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Rechercher utilisateurs, parties, transactions...',
              hintStyle: const TextStyle(color: NeonColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: NeonColors.primary, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: NeonColors.textSecondary, size: 18), onPressed: () { _controller.clear(); setState(() => _results = []); })
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeonColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeonColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: NeonColors.primary)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          if (_isSearching)
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: NeonColors.primary))
          else if (_results.isEmpty && _controller.text.length >= 2)
            const Padding(padding: EdgeInsets.all(16), child: Text('Aucun résultat', style: TextStyle(color: NeonColors.textSecondary)))
          else
            SizedBox(
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    leading: Icon(result['icon'] as IconData, color: NeonColors.primary, size: 20),
                    title: Text(result['title'] as String, style: const TextStyle(color: NeonColors.textPrimary, fontSize: 13)),
                    subtitle: Text(result['subtitle'] as String, style: const TextStyle(color: NeonColors.textSecondary, fontSize: 11)),
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go(result['route'] as String);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Affiche le dialog de recherche
void showAdminSearch(BuildContext context) {
  showDialog(context: context, builder: (context) => const AdminSearchCommand());
}
