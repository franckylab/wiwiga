# ==================================
# WIWIGA - Application GameHub Core
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub

defmodule GameHub.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_hub,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {GameHub.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:redix, "~> 1.5"},
      {:guardian, "~> 2.3"},
      {:phoenix_pubsub, "~> 2.1"}
    ]
  end
end
