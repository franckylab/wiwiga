# ==================================
# WIWIGA - Rendu de Templates {{variable}}
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.TemplateRenderer

defmodule GameHub.Notifications.TemplateRenderer do
  @moduledoc """
  Rendu des templates avec variables `{{nom}}`.

  ## Exemple
      iex> render("Bonjour {{pseudo}}, +{{montant}} jetons", %{"pseudo" => "Ali", "montant" => "500"})
      {:ok, "Bonjour Ali, +500 jetons"}
  """

  @var_regex ~r/\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}/

  @doc """
  Rend un template avec les variables fournies.

  Retourne `{:error, {:missing_variables, [...]}}` si une
  variable requise est absente.
  """
  @spec render(String.t(), map(), list(String.t())) ::
          {:ok, String.t()} | {:error, {:missing_variables, list(String.t())}}
  def render(body_tpl, variables, required_variables \\ []) do
    string_vars = stringify_keys(variables)

    missing =
      required_variables
      |> Enum.filter(fn key -> Map.get(string_vars, key) in [nil, ""] end)

    if missing != [] do
      {:error, {:missing_variables, missing}}
    else
      rendered =
        Regex.replace(@var_regex, body_tpl, fn _full, key ->
          to_string(Map.get(string_vars, key, ""))
        end)

      {:ok, rendered}
    end
  end

  @doc """
  Extrait les noms de variables d'un template.
  """
  @spec extract_variables(String.t()) :: list(String.t())
  def extract_variables(body_tpl) do
    @var_regex
    |> Regex.scan(body_tpl)
    |> Enum.map(fn [_full, key] -> key end)
    |> Enum.uniq()
  end

  defp stringify_keys(variables) when is_map(variables) do
    Map.new(variables, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify_keys(_), do: %{}
end
