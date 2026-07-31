# ==================================
# WIWIGA - Migration Fix Séquences ID
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Migration: 20260730000004_fix_id_sequences.exs
# Description: Les tables créées avec `add :id, :bigint` n'ont pas de séquence,
#              ce qui casse toute insertion Ecto (id null). Ajout des séquences.

defmodule GameHub.Repo.Migrations.FixIdSequences do
  use Ecto.Migration

  @tables ~w(users wallet_transactions game_configs audit_logs feature_flags
             responsible_gaming_limits game_timeout_configs dice_game_results)

  def up do
    Enum.each(@tables, fn table ->
      execute "CREATE SEQUENCE IF NOT EXISTS #{table}_id_seq OWNED BY #{table}.id"

      execute """
      SELECT setval('#{table}_id_seq', COALESCE((SELECT MAX(id) FROM #{table}), 0) + 1, false)
      """

      execute "ALTER TABLE #{table} ALTER COLUMN id SET DEFAULT nextval('#{table}_id_seq')"
    end)
  end

  def down do
    Enum.each(@tables, fn table ->
      execute "ALTER TABLE #{table} ALTER COLUMN id DROP DEFAULT"
      execute "DROP SEQUENCE IF EXISTS #{table}_id_seq"
    end)
  end
end
