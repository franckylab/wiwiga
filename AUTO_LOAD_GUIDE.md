# 🚀 Chargement Automatique des Rules & Skills - WIWIGA

## 📋 Vue d'ensemble

Le système de chargement automatique garantit que **toutes les règles et tous les skills sont systématiquement chargés** avant chaque génération de code par l'agent Qoder.

## 🔧 Mécanisme de Chargement

### Fichiers de Configuration Agent (Lecture Automatique)

Qoder lit **automatiquement** ces fichiers à chaque session :

1. **`.qoder/AGENTS.md`** - Configuration principale du projet
   - Situé dans le dossier `.qoder/`
   - Contient les instructions de chargement obligatoire
   - Définit le mapping tâche → skill
   
2. **`CLAUDE.md`** - Configuration complémentaire (racine du projet)
   - Situé à la racine du projet
   - Renforce les instructions de chargement
   - Fournit un résumé des contraintes critiques

### Règles (Chargement Automatique via AGENTS.md)

Toutes les règles sont **automatiquement chargées** car référencées explicitement dans AGENTS.md :

| Fichier | Contenu | Lignes |
|---------|---------|--------|
| `rl_development-best-practices.md` | 25 règles de développement (ACID, OTP, RNG, etc.) | 1093 |
| `rl_naming-conventions.md` | Conventions de nommage Elixir/Flutter | 117 |
| `rl_file-structure.md` | Structure fichiers, bannières, imports | 329 |
| `rl_responsive-design.md` | 17 breakpoints, ResponsiveConfig | 847 |

### Skills (Invocation Automatique par Détection de Tâche)

Les skills sont **automatiquement invoqués** selon le type de tâche détecté :

| Déclencheur | Skill Invoqué |
|-------------|---------------|
| Backend Elixir/Phoenix | `sk_backend-elixir-phoenix.md` |
| Frontend Flutter | `sk_frontend-flutter.md` |
| Jeu de dés | `sk_dice-game-implementation.md` |

## 🔄 Flux de Chargement Automatique

```
Interaction Utilisateur
        ↓
[Lecture automatique] AGENTS.md + CLAUDE.md
        ↓
[Chargement obligatoire] 4 fichiers de règles (rl_*)
        ↓
[Détection de tâche] Type de développement identifié
        ↓
[Invocation automatique] Skill correspondant (sk_*)
        ↓
[Génération de code] Conforme aux règles et skills
```

## ✅ Vérification du Système

Exécutez le script de vérification :

```bash
./verify-auto-load.sh
```

Ce script vérifie :
- ✅ Existence des fichiers de configuration
- ✅ Existence des 4 fichiers de règles
- ✅ Existence des 3 fichiers de skills
- ✅ Présence des références dans AGENTS.md
- ✅ Présence des références dans CLAUDE.md

## 🎯 Garanties

Grâce à ce système :

1. **Règles toujours appliquées** : Les 4 fichiers de règles sont lus avant chaque génération
2. **Skills toujours invoqués** : Le skill approprié est chargé selon le contexte
3. **Conformité garantie** : Le code généré respecte les standards WIWIGA
4. **Pas d'oubli possible** : Les instructions sont dans des fichiers lus automatiquement

## 🔍 Comment ça fonctionne techniquement

### Pourquoi c'est automatique ?

1. **AGENTS.md** est lu automatiquement par Qoder à chaque nouvelle conversation
2. **CLAUDE.md** est également lu automatiquement (convention Qoder/Anthropic)
3. Les **instructions explicites** dans ces fichiers forcent l'agent à :
   - Lire les fichiers de règles (chemins absolus fournis)
   - Détecter le type de tâche
   - Invoquer le skill correspondant (chemins absolus fournis)

### Que se passe-t-il si l'agent ne charge pas ?

Les fichiers contiennent des instructions **NON NÉGOCIABLES** avec :
- Section "🚨 CHARGEMENT AUTOMATIQUE OBLIGATOIRE" en haut
- Instructions claires "AVANT TOUTE RÉPONSE OU GÉNÉRATION DE CODE"
- Tableau de mapping explicite tâche → skill
- Règles avec emojis ✅ et ❌ pour visibilité maximale

## 📁 Structure des Fichiers

```
wiwiga/
├── CLAUDE.md                          # ⚡ Lu automatiquement (racine)
├── .qoder/
│   ├── AGENTS.md                      # ⚡ Lu automatiquement (.qoder)
│   ├── rules/
│   │   ├── rl_development-best-practices.md  # 📋 Règles dev
│   │   ├── rl_naming-conventions.md          # 📝 Nommage
│   │   ├── rl_file-structure.md              # 🏗️ Structure
│   │   └── rl_responsive-design.md           # 📱 Responsive
│   └── skills/
│       ├── sk_backend-elixir-phoenix.md      # 🔧 Backend
│       ├── sk_frontend-flutter.md            # 🎨 Frontend
│       └── sk_dice-game-implementation.md    # 🎲 Jeu de dés
└── verify-auto-load.sh                # 🔍 Script de vérification
```

## 🚨 Points Critiques

- **Ne jamais supprimer** AGENTS.md ou CLAUDE.md
- **Ne jamais retirer** les références aux fichiers rl_* et sk_*
- **Toujours exécuter** verify-auto-load.sh après modifications
- **Les préfixes** rl_ et sk_ sont obligatoires pour la cohérence

---

**Auteur**: Franck Arlos CHENDJOU  
**Date**: 24 Juin 2026  
**Projet**: WIWIGA - Hub de Jeux Multiplateforme
