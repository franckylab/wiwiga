# ==================================
# WIWIGA - Configuration OTP Umbrella
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub (Umbrella)

defmodule GameHub.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:redix, "~> 1.5"},
      {:guardian, "~> 2.3"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.7"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end
end
