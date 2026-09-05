# ==================================
# WIWIGA - Migration Backfill Sets Mode
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Description: Rend le nombre de sets configurable (fixe/aléatoire).
#   - Ajoute `sets_mode` ("fixed" par défaut), `sets_random_min/max` à
#     `game_rules.config` quand absents.
#   - Aligne `default_sets` 1 → 3 (BO3) quand il vaut encore le défaut du
#     seed initial (aucune interface admin ne permettait de le modifier
#     avant cette migration, donc 1 = défaut historique, pas un choix opérateur).
# Réversible (best-effort documenté) via `down/0`.

defmodule GameHub.Repo.Migrations.AddSetsModeToGameRules do
  use Ecto.Migration

  def up do
    # 1) Nouvelles clés (n'écrase jamais un choix opérateur existant)
    execute """
    UPDATE game_rules
    SET config = config
      || jsonb_build_object('sets_mode', COALESCE(config->>'sets_mode', 'fixed'))
      || jsonb_build_object('sets_random_min', COALESCE((config->>'sets_random_min')::int, (config->>'min_sets')::int, 1))
      || jsonb_build_object('sets_random_max', COALESCE((config->>'sets_random_max')::int, LEAST(COALESCE((config->>'max_sets')::int, 11), 5)))
    WHERE game_type = 'dice'
    """

    # 2) Défaut historique 1 (BO1) → 3 (BO3) : cohérent avec l'interface
    # (création de salle, écran de match) et la documentation moteur.
    execute """
    UPDATE game_rules
    SET config = jsonb_set(config, '{default_sets}', '3')
    WHERE game_type = 'dice'
      AND COALESCE((config->>'default_sets')::int, 1) = 1
    """
  end

  def down do
    # Retire les clés ajoutées (valeurs opérateur post-migration perdues :
    # acceptable, elles n'existaient pas avant `up`).
    execute """
    UPDATE game_rules
    SET config = config - 'sets_mode' - 'sets_random_min' - 'sets_random_max'
    WHERE game_type = 'dice'
    """

    # Restaure le défaut historique sur les lignes migrées en `up`.
    execute """
    UPDATE game_rules
    SET config = jsonb_set(config, '{default_sets}', '1')
    WHERE game_type = 'dice'
      AND COALESCE((config->>'default_sets')::int, 3) = 3
    """
  end
end
