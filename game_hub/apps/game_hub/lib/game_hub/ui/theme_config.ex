defmodule GameHub.UI.ThemeConfig do
  @moduledoc """
  Configuration du thème UI de l'application WIWIGA.
  
  Cette table est un singleton (une seule ligne) qui stocke
  tous les paramètres visuels configurables via le dashboard admin.
  
  ## Exemple
      iex> ThemeConfig.get_config()
      %ThemeConfig{primary_color: "#2DD4BF", ...}
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, warn: false
  
  alias GameHub.Repo
  alias GameHub.Users.User
  
  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, except: [:__meta__]}
  
  schema "ui_theme_configs" do
    field :primary_color, :string, default: "#2DD4BF"
    field :secondary_color, :string, default: "#F59E0B"
    field :accent_color, :string, default: "#00D9FF"
    field :background_color, :string, default: "#1E293B"
    field :surface_color, :string, default: "#0F172A"
    field :border_radius, :float, default: 12.0
    field :glow_intensity, :float, default: 0.5
    field :animation_duration, :integer, default: 200
    field :font_family_body, :string, default: "Inter"
    field :font_family_display, :string, default: "Orbitron"
    field :logo_url, :string
    field :favicon_url, :string
    
    belongs_to :updated_by, User
    
    timestamps()
  end
  
  @doc """
  Retourne la configuration du thème (singleton).
  Crée une configuration par défaut si elle n'existe pas.
  """
  def get_config do
    case Repo.one(from(t in __MODULE__, limit: 1)) do
      nil -> create_default_config()
      config -> config
    end
  end
  
  @doc """
  Met à jour la configuration du thème et broadcast le changement.
  """
  def update_config(attrs) do
    config = get_config()
    
    config
    |> changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_config} ->
        # Broadcast changement pour WebSocket
        GameHubWeb.Endpoint.broadcast!("theme:update", %{
          config: Map.from_struct(updated_config)
        })
        
        {:ok, updated_config}
      
      error -> error
    end
  end
  
  defp create_default_config do
    %__MODULE__{}
    |> changeset(%{})
    |> Repo.insert!()
  end
  
  defp changeset(theme_config, attrs) do
    theme_config
    |> cast(attrs, [
      :primary_color, :secondary_color, :accent_color,
      :background_color, :surface_color, :border_radius,
      :glow_intensity, :animation_duration, :font_family_body,
      :font_family_display, :logo_url, :favicon_url, :updated_by_id
    ])
    |> validate_required([:primary_color, :secondary_color, :background_color])
    |> validate_format(:primary_color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> validate_format(:secondary_color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> validate_format(:accent_color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> validate_format(:background_color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> validate_number(:border_radius, greater_than_or_equal_to: 0, less_than_or_equal_to: 50)
    |> validate_number(:glow_intensity, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> validate_number(:animation_duration, greater_than_or_equal_to: 50, less_than_or_equal_to: 1000)
  end
end
