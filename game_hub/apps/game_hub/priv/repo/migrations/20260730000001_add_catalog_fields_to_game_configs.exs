# ==================================
# WIWIGA - Migration Champs Catalogue Jeux
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260730000001_add_catalog_fields_to_game_configs.exs
# Description: Ajout coming_soon, tips, display_order + seeds jeux à venir

defmodule GameHub.Repo.Migrations.AddCatalogFieldsToGameConfigs do
  use Ecto.Migration

  def up do
    alter table(:game_configs) do
      add :coming_soon, :boolean, default: false, null: false
      add :tips, :map
      add :display_order, :integer, default: 0, null: false
    end

    # Index pour tri catalogue
    create index(:game_configs, [:display_order])

    # Enrichir le jeu de dés : description complète + astuces + ordre
    execute """
      UPDATE game_configs
      SET description = 'Affrontez un adversaire aux dés : celui qui obtient la meilleure somme remporte la mise. Deux règles disponibles : Normal (plus haut score) et Cible (le plus proche d''une cible votée).',
          display_order = 1,
          tips = '{"items": [
            {"title": "Commencez petit", "body": "Misez le minimum le temps de maîtriser les règles et le rythme des parties."},
            {"title": "Choisissez votre règle", "body": "En mode Normal, la plus haute somme gagne. En mode Cible, visez la valeur votée : la stratégie change complètement."},
            {"title": "Gérez votre bankroll", "body": "Ne misez jamais plus de 10% de votre solde sur une seule partie."},
            {"title": "Observez les égalités", "body": "En cas d''égalité, le set est rejoué. Restez concentré, chaque relance compte."},
            {"title": "Profitez des sets multiples", "body": "Un match se joue en plusieurs sets : perdre un set ne signifie pas perdre le match."},
            {"title": "Jouez responsable", "body": "Fixez-vous des limites de dépôt et de perte dans votre profil. Le jeu doit rester un plaisir."}
          ]}',
          updated_at = NOW()
      WHERE game_type = 'dice'
    """

    # Seeds jeux à venir : Ludo, Cartes, Roulette (coming_soon = true)
    execute """
      INSERT INTO game_configs (id, game_type, name, description, min_bet, max_bet, commission_rate, commission_mode, is_active, coming_soon, display_order, config, inserted_at, updated_at)
      VALUES
        (2, 'ludo', 'Ludo', 'Le jeu de plateau classique revisité : sortez vos pions, bloquez vos adversaires et rentrez tous vos pions en premier.', 100, 100000, 0.05, 'percentage', true, true, 2, '{}', NOW(), NOW()),
        (3, 'card', 'Cartes', 'Des parties de cartes rapides et stratégiques contre de vrais joueurs. Bluff, tactique et sang-froid.', 100, 100000, 0.05, 'percentage', true, true, 3, '{}', NOW(), NOW()),
        (4, 'roulette', 'Roulette', 'La roulette en direct : pariez sur votre numéro, votre couleur ou votre chance et tentez le gros gain.', 100, 100000, 0.05, 'percentage', true, true, 4, '{}', NOW(), NOW())
      ON CONFLICT (game_type) DO UPDATE
      SET coming_soon = EXCLUDED.coming_soon,
          display_order = EXCLUDED.display_order,
          description = EXCLUDED.description,
          updated_at = NOW()
    """
  end

  def down do
    execute "DELETE FROM game_configs WHERE game_type IN ('ludo', 'card', 'roulette') AND coming_soon = true"

    alter table(:game_configs) do
      remove :coming_soon
      remove :tips
      remove :display_order
    end
  end
end
