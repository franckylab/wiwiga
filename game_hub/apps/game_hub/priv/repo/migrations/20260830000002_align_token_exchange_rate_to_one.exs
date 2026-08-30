defmodule GameHub.Repo.Migrations.AlignTokenExchangeRateToOne do
  use Ecto.Migration

  @doc """
  Aligne le taux de conversion jetons/FCFA sur la spec WIWIGA 1:1.

  Contexte:
  - Migration initiale 20260801000001 créait token_configs avec default 10.0 (10 jetons = 1 FCFA)
  - Spec WIWIGA et TokenConfig schema exigent 1.0 (1 jeton = 1 FCFA)
  - Cette migration corrige les données existantes et le défaut DDL
  """
  def up do
    # Corriger les lignes existantes passées en 10.0 (prod) vers 1.0
    execute("UPDATE token_configs SET exchange_rate = 1.0 WHERE exchange_rate = 10.0")

    # Aligner le défaut DDL pour les futures insertions
    execute("ALTER TABLE token_configs ALTER COLUMN exchange_rate SET DEFAULT 1.0")

    # Corriger aussi les configs plateforme gaming si elles étaient stockées en centimes
    # (500000 centimes = 5000 jetons, mais label jetons) — optionnel, gardé pour audit
    # On ne touche pas aux platform_configs historiques, conversion gérée côté code via /100
  end

  def down do
    execute("ALTER TABLE token_configs ALTER COLUMN exchange_rate SET DEFAULT 10.0")
    execute("UPDATE token_configs SET exchange_rate = 10.0 WHERE exchange_rate = 1.0")
  end
end
