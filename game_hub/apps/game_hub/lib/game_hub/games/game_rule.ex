# ==================================
# WIWIGA - Schema Game Rule
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Games.GameRule
# Description: Schema Ecto pour règles de jeu configurables

defmodule GameHub.Games.GameRule do
  @moduledoc """
  Schema des règles de jeu configurables.

  Chaque type de jeu (dice, ludo, etc.) possède une ou plusieurs règles
  (normal, cible, etc.) avec une configuration JSON complète.

  ## Config Keys (dice/normal)
    - `min_sets`, `max_sets`, `default_sets`
    - `min_dice`, `max_dice`, `default_dice`
    - `dice_faces`
    - `commission_rate`
    - `min_bet`, `max_bet`
    - `min_players`, `max_players`
    - `tie_rule` ("replay" | "no_winner")
    - `turn_order` ("rotating" | "random" | "creator_first")
    - `turn_timeout_seconds`, `set_timeout_seconds`

  ## Config Keys (dice/cible)
    - Mêmes clés que normal +
    - `target_vote_mode` ("average" | "mode")
    - `vote_timeout_seconds`
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :game_type, :rule_type, :name, :description, :config, :is_active]}

  schema "game_rules" do
    field :game_type, :string
    field :rule_type, :string
    field :name, :string
    field :description, :string
    field :config, :map, default: %{}
    field :is_active, :boolean, default: true

    timestamps()
  end

  @valid_game_types ~w(dice ludo cards)
  @valid_rule_types ~w(normal cible)

  @doc """
  Changeset pour création d'une règle de jeu.
  """
  def create_changeset(rule, attrs) do
    rule
    |> cast(attrs, [:game_type, :rule_type, :name, :description, :config, :is_active])
    |> validate_required([:game_type, :rule_type, :name, :config])
    |> validate_inclusion(:game_type, @valid_game_types)
    |> validate_inclusion(:rule_type, @valid_rule_types)
    |> validate_config_keys()
    |> unique_constraint([:game_type, :rule_type])
  end

  @doc """
  Changeset pour mise à jour de la configuration.
  """
  def config_changeset(rule, config) do
    rule
    |> cast(%{config: config}, [:config])
    |> validate_required([:config])
    |> validate_config_keys()
  end

  @doc """
  Changeset pour activer/désactiver une règle.
  """
  def toggle_changeset(rule, is_active) do
    rule
    |> cast(%{is_active: is_active}, [:is_active])
  end

  # === Helpers ===

  @doc """
  Récupère une valeur de configuration avec fallback.
  """
  def get_config(%__MODULE__{config: config}, key, default \\ nil) do
    Map.get(config, key, default)
  end

  @doc """
  Récupère une valeur entière de configuration.
  """
  def get_config_int(%__MODULE__{config: config}, key, default \\ 0) do
    case Map.get(config, key) do
      nil -> default
      val when is_integer(val) -> val
      val when is_binary(val) -> String.to_integer(val)
      _ -> default
    end
  end

  @doc """
  Récupère une valeur décimale de configuration.
  """
  def get_config_decimal(%__MODULE__{config: config}, key, default \\ Decimal.new(0)) do
    case Map.get(config, key) do
      nil -> default
      val when is_float(val) -> Decimal.from_float(val)
      val when is_integer(val) -> Decimal.new(val)
      %Decimal{} = val -> val
      _ -> default
    end
  end

  # === Validation Privée ===

  defp validate_config_keys(changeset) do
    case get_field(changeset, :config) do
      nil ->
        changeset

      config when is_map(config) ->
        game_type = get_field(changeset, :game_type)

        cond do
          game_type == "dice" -> validate_dice_config(changeset, config)
          true -> changeset
        end

      _ ->
        add_error(changeset, :config, "doit être un objet JSON")
    end
  end

  defp validate_dice_config(changeset, config) do
    changeset
    |> validate_config_range(config, "min_sets", 1, 99)
    |> validate_config_range(config, "max_sets", 1, 99)
    |> validate_config_range(config, "min_dice", 1, 10)
    |> validate_config_range(config, "max_dice", 1, 10)
    |> validate_config_range(config, "dice_faces", 4, 20)
    |> validate_config_range(config, "min_bet", 0, 10_000_000)
    |> validate_config_range(config, "max_bet", 0, 10_000_000)
    |> validate_config_range(config, "min_players", 2, 10)
    |> validate_config_range(config, "max_players", 2, 10)
  end

  defp validate_config_range(changeset, config, key, min, max) do
    case Map.get(config, key) do
      nil ->
        changeset

      val when is_integer(val) ->
        if val >= min and val <= max do
          changeset
        else
          add_error(changeset, :config, "#{key} doit être entre #{min} et #{max}")
        end

      _ ->
        changeset
    end
  end
end
