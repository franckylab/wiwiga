# ==================================
# WIWIGA - Repository Ecto
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Repo

defmodule GameHub.Repo do
  @moduledoc """
  Repository Ecto pour base de données PostgreSQL.
  """
  
  use Ecto.Repo,
    otp_app: :game_hub,
    adapter: Ecto.Adapters.Postgres
  
  @doc """
  Dynamically load database configuration.
  """
  @impl true
  def init(_, opts) do
    {:ok, opts}
  end
end
