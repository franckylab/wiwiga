# Règles de Développement — WIWIGA

## Backend Elixir/Phoenix

1. **Transactions ACID** : Toute opération financière (wallet, mise, gain) DOIT utiliser `Repo.transaction/1`
2. **Génération aléatoire** : Uniquement `:crypto.strong_rand_bytes/1` côté serveur, jamais `Enum.random` côté client
3. **Idempotence** : Chaque webhook de paiement DOIT vérifier l'IdempotencyKey avant traitement
4. **GenServer** : Un état partagé = un GenServer avec supervision dans `application.ex`
5. **Cache ETS** : TTL explicite, invalidation sur update DB, fallback hardcodé si DB indisponible
6. **PubSub** : Notifications inter-process via `Phoenix.PubSub`, topics nommées `user:{id}:*`
7. **Pattern matching** : Privilégier le pattern matching dans les `case/cond` aux conditions imbriquées
8. **Specs** : `@spec` et `@doc` obligatoires sur toutes les fonctions publiques
9. **Erreurs** : Retourner `{:ok, result} | {:error, reason}`, jamais lever d'exceptions dans le flow normal
10. **Migrations** : Nommage `YYYYMMDD00000N_description.exs`, toujours réversible quand possible

## Frontend Flutter/Dart

11. **State management** : Riverpod pour tout état partagé, `ConsumerStatefulWidget` pour les écrans
12. **Repositories** : Un repository par domaine, injecté via Riverpod, retourne `Future<Map<String, dynamic>>`
13. **Models** : `fromJson/toJson` obligatoires, champs nullable avec valeurs par défaut
14. **Design system** : Utiliser UNIQUEMENT les composants néon (NeonButton, NeonCard, etc.)
15. **Thème** : `NeonColors.*` pour toute couleur, jamais de `Colors.*` ou hex hardcodé
16. **Responsive** : `LayoutBuilder` + breakpoints définis dans `rl_responsive-design.md`
17. **Navigation** : `go_router` pour la navigation déclarative, jamais de `Navigator.push` direct
18. **WebSocket** : Toujours un fallback REST si la connexion WebSocket échoue
19. **Commentaires** : En français, décrivant le POURQUOI (pas le COMMENT)
20. **Jetons** : Toujours utiliser `formatTokens()` et le terme "jetons", jamais "FCFA" dans l'UI

## Général

21. **Tests** : Chaque module backend a son fichier `test/`, chaque écran frontend a son test widget
22. **Commits** : Messages en français, format `type(scope): description` (feat, fix, refactor, test, docs)
23. **Sécurité** : Validation backend OBLIGATOIRE même si le frontend valide déjà
24. **Performance** : Pagination côté API (max 50 items), lazy loading côté Flutter
25. **Format API** : Réponse standard `{success: bool, data: dynamic, message: string}`
