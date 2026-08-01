defmodule GameHub.Repo.Migrations.CreateUIThemeConfigs do
  use Ecto.Migration

  def change do
    create table(:ui_theme_configs, primary_key: false) do
      add :id, :bigint, primary_key: true
      add :primary_color, :string, default: "#2DD4BF"
      add :secondary_color, :string, default: "#F59E0B"
      add :accent_color, :string, default: "#00D9FF"
      add :background_color, :string, default: "#1E293B"
      add :surface_color, :string, default: "#0F172A"
      add :border_radius, :float, default: 12.0
      add :glow_intensity, :float, default: 0.5
      add :animation_duration, :integer, default: 200
      add :font_family_body, :string, default: "Inter"
      add :font_family_display, :string, default: "Orbitron"
      add :logo_url, :string
      add :favicon_url, :string
      add :updated_by, references(:users, on_delete: :nilify_all)
      
      timestamps()
    end

    create index(:ui_theme_configs, [:updated_by])
    
    # Constraint pour garantir une seule ligne de configuration
    execute """
      CREATE UNIQUE INDEX ui_theme_configs_singleton_idx ON ui_theme_configs ((1))
    """
  end
end
