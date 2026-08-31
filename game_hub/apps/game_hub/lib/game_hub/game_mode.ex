# ==================================
# WIWIGA - Module GameMode (Référentiel modes de jeu)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameMode
# Description: Référentiel centralisé des modes de jeu WIWIGA
# Migration brutale 2026-08-30: "Mise en ligne"/"betting"/"pari" SUPPRIMÉS — uniquement free/staked

defmodule GameHub.GameMode do
  import Kernel, except: [to_string: 1]

  @moduledoc """
  Référentiel centralisé des modes de jeu WIWIGA — migration brutale.

  ## Modes canoniques (SEULS valides depuis 2026-08-30)
    - `:free`   → Partie sans mise (gratuit) — amicale, sans enjeu en jetons.
    - `:staked` → Partie avec mise — avec mise en jetons, gains et commissions.

  ## Rupture
    Les anciens identifiants `:betting` / `"betting"` / `"pari"` / `"mise en ligne"` sont
    **SUPPRIMÉS** sans rétro-compatibilité. Toute valeur hors `free`/`staked` est invalide.

  ## Usage
      iex> GameHub.GameMode.parse("staked")
      :staked
      iex> GameHub.GameMode.parse("free")
      :free
      iex> GameHub.GameMode.parse("betting")
      ** (ArgumentError) mode invalide
  """

  @type t :: :free | :staked

  @free :free
  @staked :staked

  # Seuls les identifiants canoniques + français sans alias historique
  @free_strings ~w(free sans_mise without_stake gratuit sans-mise)
  @staked_strings ~w(staked avec_mise with_stake avec-mise)

  @display_labels %{
    free: "Partie sans mise (gratuit)",
    staked: "Partie avec mise"
  }

  @short_labels %{
    free: "Sans mise",
    staked: "Avec mise"
  }

  @subtitles %{
    free: "Gratuit • Entre amis",
    staked: "Jetons en jeu"
  }

  @descriptions %{
    free: "Partie amicale sans enjeu — idéale pour jouer entre amis.",
    staked: "Partie avec mise en jetons — gains réels après commission."
  }

  # === Parsing strict (brutal, sans alias betting) ===

  @doc """
  Parse strictement une valeur brute vers le mode canonique.

  Seuls `"free"`/`"staked"` (et variantes françaises `sans_mise`/`avec_mise`) sont acceptés.
  Lève `ArgumentError` si invalide — pas de fallback silencieux.

  ## Examples
      iex> parse("free")
      :free
      iex> parse("staked")
      :staked
      iex> parse("Avec_Mise")
      :staked
  """
  @spec parse(String.t() | atom() | nil) :: t()
  def parse(nil), do: raise(ArgumentError, "mode requis: free | staked")
  def parse(mode) when is_atom(mode) do
    mode |> Atom.to_string() |> parse()
  end
  def parse(mode) when is_binary(mode) do
    normalized =
      mode
      |> String.trim()
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.replace("-", "_")

    cond do
      normalized in @free_strings -> @free
      normalized in @staked_strings -> @staked
      normalized == "free" -> @free
      normalized == "staked" -> @staked
      true -> raise ArgumentError, "mode invalide: #{inspect(mode)} — attendu free | staked"
    end
  end

  @doc """
  Parse avec validation retournant {:ok, mode} | {:error, :invalid_mode}.
  """
  @spec parse_strict(String.t() | atom() | nil) :: {:ok, t()} | {:error, :invalid_mode}
  def parse_strict(nil), do: {:error, :invalid_mode}
  def parse_strict(mode) when is_atom(mode), do: mode |> Atom.to_string() |> parse_strict()
  def parse_strict(mode) when is_binary(mode) do
    normalized =
      mode
      |> String.trim()
      |> String.downcase()
      |> String.replace(" ", "_")
      |> String.replace("-", "_")

    cond do
      normalized in @free_strings -> {:ok, @free}
      normalized in @staked_strings -> {:ok, @staked}
      true -> {:error, :invalid_mode}
    end
  end

  @doc """
  Normalise un atome/string vers le canonique. Lève si invalide.
  """
  @spec normalize(t() | atom() | String.t()) :: t()
  def normalize(:staked), do: @staked
  def normalize(:free), do: @free
  def normalize(other) when is_atom(other), do: parse(other)
  def normalize(other) when is_binary(other), do: parse(other)

  # === Sérialisation ===

  @doc """
  Sérialise le mode canonique vers sa représentation API (string).
  """
  @spec to_string(t() | atom()) :: String.t()
  def to_string(mode) when is_atom(mode) do
    case normalize(mode) do
      :free -> "free"
      :staked -> "staked"
    end
  end
  def to_string(mode) when is_binary(mode), do: mode |> parse() |> to_string()

  @spec to_api_string(t() | atom()) :: String.t()
  def to_api_string(mode), do: to_string(mode)

  # === Helpers d'affichage (FR) ===

  @spec display_label(t() | atom() | String.t()) :: String.t()
  def display_label(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@display_labels, m) end)
  end

  @spec short_label(t() | atom() | String.t()) :: String.t()
  def short_label(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@short_labels, m) end)
  end

  @spec subtitle(t() | atom() | String.t()) :: String.t()
  def subtitle(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@subtitles, m) end)
  end

  @spec description(t() | atom() | String.t()) :: String.t()
  def description(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@descriptions, m) end)
  end

  # === Prédicats ===

  @spec free?(t() | atom() | String.t()) :: boolean()
  def free?(mode), do: normalize(mode) == @free

  @spec staked?(t() | atom() | String.t()) :: boolean()
  def staked?(mode), do: normalize(mode) == @staked

  # === Listes ===

  @spec all() :: [t()]
  def all, do: [@free, @staked]

  @spec api_values() :: [String.t()]
  def api_values, do: ["free", "staked"]

  @spec accepted_strings() :: [String.t()]
  def accepted_strings, do: @free_strings ++ @staked_strings

  @spec valid?(String.t() | atom()) :: boolean()
  def valid?(mode) when is_atom(mode), do: valid?(Atom.to_string(mode))
  def valid?(mode) when is_binary(mode) do
    case parse_strict(mode) do
      {:ok, _} -> true
      _ -> false
    end
  end
  def valid?(_), do: false

  @spec canonical?(String.t() | atom()) :: boolean()
  def canonical?(mode) when is_atom(mode), do: mode in [@free, @staked]
  def canonical?(mode) when is_binary(mode), do: mode in ["free", "staked"]
  def canonical?(_), do: false
end
