# ==================================
# WIWIGA - Module GameMode (Référentiel modes de jeu)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.GameMode
# Description: Référentiel centralisé des modes de jeu WIWIGA
# Refactor: Remplace "Mise en ligne" par désignation claire Partie sans/avec mise

defmodule GameHub.GameMode do
  import Kernel, except: [to_string: 1]

  @moduledoc """
  Référentiel centralisé des modes de jeu WIWIGA.

  ## Modes canoniques
    - `:free`   → Partie sans mise (gratuit) — partie amicale, sans enjeu en jetons.
    - `:staked` → Partie avec mise — partie avec mise en jetons, gains et commissions.

  ## Rétro-compatibilité
    L'ancien identifiant `:betting` / `"betting"` (et `"pari"`, `"mise en ligne"`) est
    conservé comme **alias** de `:staked`. Tout parsage normalise automatiquement vers `:staked`.

    Valeurs d'entrée acceptées (insensible à la casse, trim) :
      - `:free`   ← "free", "sans_mise", "without_stake", "gratuit"
      - `:staked` ← "staked", "betting", "avec_mise", "with_stake", "pari", "mise"

  ## Usage
      iex> GameHub.GameMode.parse("betting")
      :staked
      iex> GameHub.GameMode.to_string(:staked)
      "staked"
      iex> GameHub.GameMode.display_label(:free)
      "Partie sans mise (gratuit)"
  """

  @type t :: :free | :staked

  @free :free
  @staked :staked

  # Alias historiques
  @betting :betting

  @free_strings ~w(free sans_mise without_stake gratuit sans-mise)
  @staked_strings ~w(staked betting avec_mise with_stake pari mise avec-mise mise_en_ligne)

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

  # === Parsing ===

  @doc """
  Parse une valeur brute (string/atom/nil) vers le mode canonique.

  Normalise automatiquement l'alias historique `"betting"` → `:staked`.

  ## Examples
      iex> parse("free")
      :free
      iex> parse("betting")
      :staked
      iex> parse("Avec_Mise")
      :staked
      iex> parse(nil)
      :free
  """
  @spec parse(String.t() | atom() | nil) :: t()
  def parse(nil), do: @free
  def parse(mode) when is_atom(mode) do
    mode
    |> Atom.to_string()
    |> parse()
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
      normalized == "staked" -> @staked
      normalized == "free" -> @free
      true -> @free
    end
  end

  @doc """
  Parse avec validation stricte : retourne {:ok, mode} ou {:error, :invalid_mode}.
  """
  @spec parse_strict(String.t() | atom() | nil) :: {:ok, t()} | {:error, :invalid_mode}
  def parse_strict(nil), do: {:ok, @free}
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
  Normalise un atome potentiellement historique (`:betting`) vers `:staked`.
  """
  @spec normalize(t() | atom()) :: t()
  def normalize(:betting), do: @staked
  def normalize(@betting), do: @staked
  def normalize(:staked), do: @staked
  def normalize(:free), do: @free
  def normalize(other) when is_atom(other), do: parse(other)
  def normalize(other) when is_binary(other), do: parse(other)
  def normalize(_), do: @free

  # === Sérialisation ===

  @doc """
  Sérialise le mode canonique vers sa représentation API (string).

  Toujours `"free"` ou `"staked"` — jamais `"betting"` (alias déprécié).

  ## Examples
      iex> to_string(:free)
      "free"
      iex> to_string(:betting)
      "staked"
  """
  @spec to_string(t() | atom()) :: String.t()
  def to_string(mode) when is_atom(mode) do
    case normalize(mode) do
      :free -> "free"
      :staked -> "staked"
    end
  end
  def to_string(mode) when is_binary(mode), do: mode |> parse() |> to_string()

  @doc """
  Alias de `to_string/1` pour clarté API.
  """
  @spec to_api_string(t() | atom()) :: String.t()
  def to_api_string(mode), do: to_string(mode)

  # === Helpers d'affichage (FR) ===

  @doc """
  Label complet français pour UI.

  - `:free` → "Partie sans mise (gratuit)"
  - `:staked` → "Partie avec mise"
  """
  @spec display_label(t() | atom() | String.t()) :: String.t()
  def display_label(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@display_labels, m, "Partie sans mise (gratuit)") end)
  end

  @doc """
  Label court français.

  - `:free` → "Sans mise"
  - `:staked` → "Avec mise"
  """
  @spec short_label(t() | atom() | String.t()) :: String.t()
  def short_label(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@short_labels, m, "Sans mise") end)
  end

  @doc """
  Sous-titre explicatif.
  """
  @spec subtitle(t() | atom() | String.t()) :: String.t()
  def subtitle(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@subtitles, m, "") end)
  end

  @doc """
  Description longue.
  """
  @spec description(t() | atom() | String.t()) :: String.t()
  def description(mode) do
    mode |> normalize() |> then(fn m -> Map.get(@descriptions, m, "") end)
  end

  # === Prédicats ===

  @spec free?(t() | atom() | String.t()) :: boolean()
  def free?(mode), do: normalize(mode) == @free

  @spec staked?(t() | atom() | String.t()) :: boolean()
  def staked?(mode), do: normalize(mode) == @staked

  @doc """
  Alias déprécié : `betting?` → `staked?`.
  """
  @spec betting?(t() | atom() | String.t()) :: boolean()
  def betting?(mode), do: staked?(mode)

  # === Listes ===

  @doc "Liste des modes canoniques."
  @spec all() :: [t()]
  def all, do: [@free, @staked]

  @doc "Valeurs string canoniques pour API/docs."
  @spec api_values() :: [String.t()]
  def api_values, do: ["free", "staked"]

  @doc "Valeurs acceptées (incluant alias historiques) pour validation souple."
  @spec accepted_strings() :: [String.t()]
  def accepted_strings, do: @free_strings ++ @staked_strings ++ ["staked", "free"]

  @doc "Vérifie si une valeur est un mode valide (incluant alias)."
  @spec valid?(String.t() | atom()) :: boolean()
  def valid?(mode) when is_atom(mode), do: valid?(Atom.to_string(mode))
  def valid?(mode) when is_binary(mode) do
    case parse_strict(mode) do
      {:ok, _} -> true
      _ -> false
    end
  end
  def valid?(_), do: false

  @doc "Vérifie si une valeur est strictement canonique (free/staked)."
  @spec canonical?(String.t() | atom()) :: boolean()
  def canonical?(mode) when is_atom(mode), do: mode in [@free, @staked]
  def canonical?(mode) when is_binary(mode), do: mode in ["free", "staked"]
  def canonical?(_), do: false
end
