# ============================================================
# Fichier: game_hub_web.ex
# Description: Module helper Phoenix avec macros use
# Auteur: WIWIGA Team
# Date: 2026-06-23
# ============================================================

defmodule GameHubWeb do
  @moduledoc """
  Module helper qui définit les macros use pour Phoenix.
  """

  # Controller
  def controller do
    quote do
      use Phoenix.Controller,
        namespace: GameHubWeb,
        formats: [:json],
        layouts: [html: GameHubWeb.Layouts]

      import Plug.Conn
      import Ecto.Query
    end
  end

  # View (pour compatibilité Phoenix 1.7)
  def view do
    quote do
      use Phoenix.View,
        root: "lib/game_hub_web/templates",
        namespace: GameHubWeb

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]
    end
  end

  # Router
  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  # Channel
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  # Endpoint (déjà défini)
  def endpoint do
    quote do
      use Phoenix.Endpoint
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
