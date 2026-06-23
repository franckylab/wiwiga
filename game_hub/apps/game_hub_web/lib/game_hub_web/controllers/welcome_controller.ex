defmodule GameHubWeb.WelcomeController do
  @moduledoc """
  Controller pour la page d'accueil de l'API WIWIGA.
  """

  use GameHubWeb, :controller

  @doc """
  Retourne les informations de l'API.
  """
  def index(conn, _params) do
    json(conn, %{
      success: true,
      message: "Bienvenue sur l'API WIWIGA",
      version: "0.1.0",
      documentation: "/api/docs",
      endpoints: %{
        authentication: "/api/auth/*",
        wallet: "/api/wallet/*",
        games: "/api/games",
        webhooks: "/api/webhooks/*"
      },
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end
end
