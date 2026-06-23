defmodule GameHub.Guardian do
  @moduledoc """
  Module Guardian pour la gestion des tokens JWT.
  """
  
  use Guardian, otp_app: :game_hub
  
  alias GameHub.Users.User
  alias GameHub.Repo
  
  @doc """
  Construit les claims pour le token JWT.
  """
  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end
  
  @doc """
  Récupère l'utilisateur depuis le token.
  """
  def resource_from_claims(%{"sub" => user_id}) do
    case Repo.get(User, user_id) do
      nil -> {:error, :resource_not_found}
      user -> {:ok, user}
    end
  end
  
  def resource_from_claims(_claims) do
    {:error, :invalid_claims}
  end
end
