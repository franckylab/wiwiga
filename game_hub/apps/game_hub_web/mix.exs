# ==================================
# WIWIGA - Application Web Phoenix
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb

defmodule GameHubWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :game_hub_web,
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
      mod: {GameHubWeb.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:cowboy, "~> 2.10"},
      {:game_hub, in_umbrella: true}
    ]
  end
end
