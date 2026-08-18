# ==================================
# WIWIGA - Migration Admin 2FA TOTP
# ==================================
# Module: Add admin 2FA support
# Description: Ajoute le champ totp_secret sur users pour le 2FA admin

defmodule GameHub.Repo.Migrations.AddAdminTwoFactorAuth do
  use Ecto.Migration

  def change do
    # Ajouter le champ totp_secret sur la table users pour le 2FA admin
    alter table(:users) do
      add :totp_secret, :string
      add :totp_enabled, :boolean, default: false
      add :totp_activated_at, :utc_datetime
    end

    create index(:users, [:totp_enabled])
  end
end
