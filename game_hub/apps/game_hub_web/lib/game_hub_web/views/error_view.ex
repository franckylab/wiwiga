defmodule GameHubWeb.ErrorView do
  @moduledoc """
  Vue pour gérer les erreurs HTTP.
  """

  def render("404.json", _assigns) do
    %{error: "Resource not found"}
  end

  def render("500.json", _assigns) do
    %{error: "Internal server error"}
  end

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
