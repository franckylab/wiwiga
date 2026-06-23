# ==================================
# WIWIGA - Plugin Jeu de Dés OTP
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: DiceGame

defmodule DiceGame.MixProject do
  use Mix.Project

  def project do
    [
      app: :dice_game,
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
      mod: {DiceGame.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:game_hub, in_umbrella: true}
    ]
  end
end
