# ==================================
# WIWIGA - Module Sessions Utilisateur
# ==================================
# Module: GameHub.Users.Sessions
# Description: Gestion des sessions actives
#              Tracking appareils, révocation

defmodule GameHub.Users.Sessions do
  @moduledoc """
  Gestion des sessions utilisateur.
  
  Permet de tracker les appareils connectés,
  de révoquer des sessions, et de limiter les connexions simultanées.
  """
  
  import Ecto.Query
  alias GameHub.{Repo, Users.UserSession}
  
  @session_max_age_days 30
  
  @doc """
  Crée une nouvelle session.
  Appelé à chaque login/verify_otp réussi.
  """
  def create_session(user_id, opts \\ []) do
    device_id = Keyword.get(opts, :device_id)
    user_agent = Keyword.get(opts, :user_agent, "unknown")
    ip_address = Keyword.get(opts, :ip_address, "unknown")
    
    # Marquer les anciennes sessions du même device comme non-courantes
    if device_id do
      from(s in UserSession,
        where: s.user_id == ^user_id and s.device_id == ^device_id,
        update: [set: [is_current: false]]
      )
      |> Repo.update_all([])
    end
    
    attrs = %{
      user_id: user_id,
      device_id: device_id,
      user_agent: String.slice(user_agent, 0, 500),
      ip_address: ip_address,
      last_active_at: DateTime.utc_now() |> DateTime.truncate(:second),
      is_current: true
    }
    
    %UserSession{}
    |> UserSession.changeset(attrs)
    |> Repo.insert()
  end
  
  @doc """
  Liste les sessions actives d'un utilisateur.
  """
  def get_active_sessions(user_id) do
    sessions = Repo.all(
      from s in UserSession,
      where: s.user_id == ^user_id and s.is_current == true,
      order_by: [desc: s.last_active_at],
      limit: 20
    )
    
    {:ok, sessions}
  end
  
  @doc """
  Révoque une session spécifique.
  """
  def revoke_session(user_id, session_id) do
    case Repo.get_by(UserSession, id: session_id, user_id: user_id) do
      nil ->
        {:error, :session_not_found}
      
      session ->
        session
        |> UserSession.changeset(%{is_current: false})
        |> Repo.update()
    end
  end
  
  @doc """
  Révoque toutes les sessions sauf la courante.
  """
  def revoke_all_other_sessions(user_id, current_session_id \\ nil) do
    query = from s in UserSession,
      where: s.user_id == ^user_id and s.is_current == true
    
    query = if current_session_id do
      from s in query, where: s.id != ^current_session_id
    else
      query
    end
    
    Repo.update_all(query, set: [is_current: false])
    :ok
  end
  
  @doc """
  Met à jour le last_active_at d'une session.
  """
  def touch_session(session_id) do
    from(s in UserSession,
      where: s.id == ^session_id,
      update: [set: [last_active_at: fragment("NOW()")]]
    )
    |> Repo.update_all([])
    
    :ok
  end
  
  @doc """
  Nettoie les sessions expirées (> 30 jours).
  """
  def cleanup_expired_sessions do
    cutoff = DateTime.utc_now() |> DateTime.add(-@session_max_age_days * 86400, :second)
    
    from(s in UserSession,
      where: s.last_active_at < ^cutoff,
      update: [set: [is_current: false]]
    )
    |> Repo.update_all([])
    
    :ok
  end
  
  @doc """
  Détecte le nom d'appareil depuis le user_agent.
  """
  def detect_device_name(user_agent) when is_binary(user_agent) do
    cond do
      String.contains?(user_agent, "iPhone") -> "iPhone"
      String.contains?(user_agent, "iPad") -> "iPad"
      String.contains?(user_agent, "Android") -> "Android"
      String.contains?(user_agent, "Macintosh") -> "Mac"
      String.contains?(user_agent, "Windows") -> "Windows PC"
      String.contains?(user_agent, "Linux") -> "Linux"
      true -> "Appareil inconnu"
    end
  end
  
  def detect_device_name(_), do: "Appareil inconnu"
end
