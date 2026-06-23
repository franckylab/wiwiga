defmodule GameHub.Errors do
  @moduledoc """
  Helpers pour la gestion des erreurs API.
  """

  @doc """
  Formatte une erreur API.
  """
  def error(message, status \\ 400, code \\ "UNKNOWN_ERROR", details \\ nil) do
    %{
      error: %{
        message: message,
        code: code,
        status: status,
        details: details
      }
    }
  end
end
