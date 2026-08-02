# ==================================
# WIWIGA - Migration OTP Preferences
# ==================================
# Ajoute les préférences OTP utilisateur
# OTP requis à la connexion (opt-in)

defmodule GameHub.Repo.Migrations.AddOtpPreferencesToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      # OTP requis à la connexion (désactivé par défaut)
      add :otp_required_on_login, :boolean, default: false, null: false
    end
  end
end
