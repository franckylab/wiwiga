defmodule DiceGame.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Workers et superviseurs ici
    ]

    opts = [strategy: :one_for_one, name: DiceGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
