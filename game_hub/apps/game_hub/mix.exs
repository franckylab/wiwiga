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
      {:phoenix, "~> 1.7"},
      {:phoenix_pubsub, "~> 2.1"},
      {:pbkdf2_elixir, "~> 2.0"},
      # Notifications multi-canal (Phase 1)
      # FCM v1 : client Finch direct (credentials depuis la DB, pas au boot)
      {:oban, "~> 2.17"},
      {:swoosh, "~> 1.16"},
      {:gen_smtp, "~> 1.0"},
      {:finch, "~> 0.18"}
    ]
  end
end
