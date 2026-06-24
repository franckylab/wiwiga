# ==================================
# WIWIGA - Plug Security Headers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.SecurityHeaders
# Description: En-têtes de sécurité HTTP (Règle 15)

defmodule GameHubWeb.SecurityHeaders do
  @moduledoc """
  Plug pour ajouter les en-têtes de sécurité HTTP.
  
  Règle 15 : TOUJOURS inclure 7 en-têtes obligatoires.
  """
  
  import Plug.Conn
  
  @doc """
  Initialise le plug.
  """
  def init(opts), do: opts
  
  @doc """
  Ajoute les en-têtes de sécurité à la réponse.
  """
  def call(conn, _opts) do
    conn
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("content-security-policy", "default-src 'self'; script-src 'self'")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", "camera=(), microphone=(), geolocation=()")
  end
end
