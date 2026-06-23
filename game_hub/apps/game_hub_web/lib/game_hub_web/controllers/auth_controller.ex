# ==================================
# WIWIGA - Controller Authentification
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHubWeb.AuthController
# Description: Endpoints OTP + JWT

defmodule GameHubWeb.AuthController do
  @moduledoc """
  Controller authentification par OTP SMS.
  
  ## Endpoints
    POST /api/auth/send-otp      - Envoie code SMS
    POST /api/auth/verify-otp    - Vérifie OTP, retourne JWT
    POST /api/auth/refresh       - Refresh token JWT
  """
  
  use GameHubWeb, :controller
  
  alias GameHub.Auth
  alias GameHub.Errors
  
  @doc """
  POST /api/auth/send-otp
  
  Body: %{phone: "+237612345678"}
  
  Response: %{success: true, message: "OTP envoyé"}
  """
  def send_otp(conn, %{"phone" => phone}) do
    case Auth.send_otp(phone) do
      {:ok, message} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{message: message},
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, :invalid_phone} ->
        conn
        |> put_status(400)
        |> json(Errors.error("Numéro de téléphone invalide", 400, "VALIDATION_ERROR", %{phone: "doit commencer par +237"}))
    end
  end
  
  def send_otp(conn, _params) do
    conn
    |> put_status(400)
    |> json(Errors.error("Paramètre 'phone' requis", 400, "VALIDATION_ERROR"))
  end
  
  @doc """
  POST /api/auth/verify-otp
  
  Body: %{phone: "+237612345678", otp: "123456"}
  
  Response: %{success: true, data: %{token: "jwt...", user: %{...}}}
  """
  def verify_otp(conn, %{"phone" => phone, "otp" => otp}) do
    case Auth.verify_otp(phone, otp) do
      {:ok, jwt_token, user} ->
        conn
        |> put_status(200)
        |> json(%{
          success: true,
          data: %{
            token: jwt_token,
            user: %{
              id: user.id,
              phone: user.phone,
              balance: user.balance,
              is_active: user.is_active
            }
          },
          meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
        })
      
      {:error, :invalid_otp} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Code OTP incorrect", 401, "INVALID_OTP"))
      
      {:error, :otp_expired} ->
        conn
        |> put_status(401)
        |> json(Errors.error("Code OTP expiré. Demandez un nouveau code.", 401, "OTP_EXPIRED"))
      
      {:error, :otp_not_found} ->
        conn
        |> put_status(404)
        |> json(Errors.error("Aucun OTP trouvé. Demandez d'abord un code.", 404, "OTP_NOT_FOUND"))
    end
  end
  
  def verify_otp(conn, _params) do
    conn
    |> put_status(400)
    |> json(Errors.error("Paramètres 'phone' et 'otp' requis", 400, "VALIDATION_ERROR"))
  end
  
  @doc """
  POST /api/auth/refresh
  
  Header: Authorization: Bearer <token>
  
  Response: %{success: true, data: %{token: "new_jwt..."}}
  """
  def refresh(conn, _params) do
    case get_bearer_token(conn) do
      nil ->
        conn
        |> put_status(401)
        |> json(Errors.error("Token JWT requis", 401, "UNAUTHORIZED"))
      
      jwt_token ->
        case Auth.refresh_jwt_token(jwt_token) do
          {:ok, new_token, _user} ->
            
            conn
            |> put_status(200)
            |> json(%{
              success: true,
              data: %{token: new_token},
              meta: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}
            })
          
          {:error, _} ->
            conn
            |> put_status(401)
            |> json(Errors.error("Token JWT invalide ou expiré", 401, "INVALID_TOKEN"))
        end
    end
  end
  
  # === Fonctions Privées ===
  
  defp get_bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> token
      _ -> nil
    end
  end
end
