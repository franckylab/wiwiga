# ==================================
# WIWIGA - Module Friends
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Friends
# Description: Gestion complète du système d'amis

defmodule GameHub.Friends do
  @moduledoc """
  Module central de gestion des amis.

  ## Fonctionnalités
  - Envoi/acceptation/rejet de demandes d'amis
  - Recherche par téléphone ou username
  - Blocage d'utilisateurs
  - Feed d'activité entre amis
  - Leaderboard entre amis
  - Ajout après partie
  - Chat (messages courts + emojis)
  """

  import Ecto.Query
  alias GameHub.Repo
  alias GameHub.Friends.{Friendship, FriendMessage, FriendActivity}
  alias GameHub.Users.User

  # === Demandes d'amis ===

  @doc """
  Envoie une demande d'ami par téléphone ou username.
  """
  def send_friend_request(from_id, %{"phone" => phone}) do
    case Repo.get_by(User, phone: phone) do
      nil -> {:error, :user_not_found}
      target_user -> send_friend_request(from_id, target_user.id)
    end
  end

  def send_friend_request(from_id, %{"username" => name}) do
    query = from u in User, where: ilike(u.name, ^"%#{name}%") and u.id != ^from_id, limit: 1
    case Repo.one(query) do
      nil -> {:error, :user_not_found}
      target_user -> send_friend_request(from_id, target_user.id)
    end
  end

  def send_friend_request(from_id, to_id) when is_integer(to_id) or is_binary(to_id) do
    to_id = to_integer(to_id)
    from_id_int = to_integer(from_id)

    # Vérifier qu'on ne s'ajoute pas soi-même
    if from_id_int == to_id, do: {:error, :cannot_add_self}, else: do_send_request(from_id_int, to_id)
  end

  defp do_send_request(from_id, to_id) do
    # Vérifier si une relation existe déjà
    existing = Repo.one(
      from f in Friendship,
        where: (f.user_id == ^from_id and f.friend_id == ^to_id) or
               (f.user_id == ^to_id and f.friend_id == ^from_id),
        limit: 1
    )

    case existing do
      nil ->
        %Friendship{}
        |> Friendship.create_changeset(%{user_id: from_id, friend_id: to_id, status: "pending"})
        |> Repo.insert()
        |> case do
          {:ok, friendship} ->
            notify_friend(to_id, "friend_request", %{from_user_id: from_id})
            {:ok, friendship}
          {:error, changeset} -> {:error, changeset}
        end

      %{status: "blocked"} ->
        {:error, :user_blocked}

      %{status: "accepted"} ->
        {:error, :already_friends}

      %{status: "pending", user_id: ^to_id} ->
        # L'autre utilisateur a déjà envoyé une demande → auto-accepter
        existing
        |> Friendship.accept_changeset()
        |> Repo.update()
        |> case do
          {:ok, friendship} ->
            notify_friend(from_id, "friend_accepted", %{from_user_id: to_id})
            notify_friend(to_id, "friend_accepted", %{from_user_id: from_id})
            {:ok, friendship}
          {:error, changeset} -> {:error, changeset}
        end

      %{status: "pending"} ->
        {:error, :request_already_pending}
    end
  end

  @doc """
  Accepte une demande d'ami.
  """
  def accept_friend_request(user_id, request_id) do
    user_id = to_integer(user_id)

    case Repo.get(Friendship, request_id) do
      nil ->
        {:error, :request_not_found}

      %{friend_id: ^user_id, status: "pending"} = friendship ->
        friendship
        |> Friendship.accept_changeset()
        |> Repo.update()
        |> case do
          {:ok, updated} ->
            notify_friend(friendship.user_id, "friend_accepted", %{from_user_id: user_id})
            record_activity(user_id, "friend_added", %{friend_id: friendship.user_id})
            {:ok, updated}
          {:error, changeset} -> {:error, changeset}
        end

      _ ->
        {:error, :invalid_request}
    end
  end

  @doc """
  Rejette une demande d'ami.
  """
  def reject_friend_request(user_id, request_id) do
    user_id = to_integer(user_id)

    case Repo.get(Friendship, request_id) do
      %{friend_id: ^user_id, status: "pending"} = friendship ->
        Repo.delete(friendship)

      nil ->
        {:error, :request_not_found}

      _ ->
        {:error, :invalid_request}
    end
  end

  @doc """
  Supprime un ami.
  """
  def remove_friend(user_id, friend_id) do
    user_id = to_integer(user_id)
    friend_id = to_integer(friend_id)

    case Repo.one(
      from f in Friendship,
        where: (f.user_id == ^user_id and f.friend_id == ^friend_id) or
               (f.user_id == ^friend_id and f.friend_id == ^user_id),
        where: f.status == "accepted"
    ) do
      nil -> {:error, :not_friends}
      friendship -> Repo.delete(friendship)
    end
  end

  @doc """
  Bloque un utilisateur.
  """
  def block_user(user_id, blocked_id) do
    user_id = to_integer(user_id)
    blocked_id = to_integer(blocked_id)

    # Supprimer toute relation existante
    Repo.delete_all(
      from f in Friendship,
        where: (f.user_id == ^user_id and f.friend_id == ^blocked_id) or
               (f.user_id == ^blocked_id and f.friend_id == ^user_id)
    )

    # Créer une relation bloquée
    %Friendship{}
    |> Friendship.create_changeset(%{user_id: user_id, friend_id: blocked_id, status: "blocked"})
    |> Repo.insert()
  end

  # === Listes ===

  @doc """
  Liste les amis d'un utilisateur avec statut en ligne.
  """
  def list_friends(user_id) do
    user_id = to_integer(user_id)

    # Amis où user_id est user_id ou friend_id
    query = from f in Friendship,
      where: f.status == "accepted" and (f.user_id == ^user_id or f.friend_id == ^user_id),
      select: f

    friendships = Repo.all(query)

    Enum.map(friendships, fn f ->
      friend_id = if f.user_id == user_id, do: f.friend_id, else: f.user_id

      case Repo.get(User, friend_id) do
        nil ->
          %{id: friend_id, name: "Inconnu", status: "offline", friendship_id: f.id}

        user ->
          %{
            id: user.id,
            name: user.name,
            phone: user.phone,
            status: get_online_status(user.id),
            friendship_id: f.id,
            created_at: f.inserted_at
          }
      end
    end)
  end

  @doc """
  Liste les demandes d'amis en attente.
  """
  def list_pending_requests(user_id) do
    user_id = to_integer(user_id)

    query = from f in Friendship,
      where: f.friend_id == ^user_id and f.status == "pending",
      order_by: [desc: f.inserted_at]

    Repo.all(query)
    |> Enum.map(fn f ->
      case Repo.get(User, f.user_id) do
        nil -> %{id: f.id, from_user: %{id: f.user_id, name: "Inconnu"}, created_at: f.inserted_at}
        user -> %{id: f.id, from_user: %{id: user.id, name: user.name, phone: user.phone}, created_at: f.inserted_at}
      end
    end)
  end

  @doc """
  Recherche un joueur par téléphone ou nom.
  """
  def search_player(user_id, query_string) do
    user_id = to_integer(user_id)

    cond do
      String.match?(query_string, ~r/^\+?\d/) ->
        # Recherche par téléphone
        Repo.all(
          from u in User,
            where: u.id != ^user_id and like(u.phone, ^"%#{query_string}%"),
            limit: 20
        )

      true ->
        # Recherche par nom
        Repo.all(
          from u in User,
            where: u.id != ^user_id and ilike(u.name, ^"%#{query_string}%"),
            limit: 20
        )
    end
    |> Enum.map(fn u ->
      %{id: u.id, name: u.name, phone: u.phone}
    end)
  end

  @doc """
  Ajoute un ami depuis une partie (après match).
  """
  def add_friend_from_game(user_id, opponent_id) do
    send_friend_request(user_id, opponent_id)
  end

  # === Leaderboard ===

  @doc """
  Classement entre amis (basé sur les parties gagnées).
  """
  def get_friend_leaderboard(user_id) do
    user_id = to_integer(user_id)
    friend_ids = get_accepted_friend_ids(user_id) ++ [user_id]

    # Compter les victoires depuis dice_game_results
    query = from r in "dice_game_results",
      where: r.winner_id in ^friend_ids,
      group_by: r.winner_id,
      select: {r.winner_id, count(r.id)},
      order_by: [desc: count(r.id)]

    results = Repo.all(query)

    # Enrichir avec les noms
    Enum.map(results, fn {winner_id, wins} ->
      case Repo.get(User, winner_id) do
        nil -> %{id: winner_id, name: "Inconnu", wins: wins}
        user -> %{id: user.id, name: user.name, wins: wins}
      end
    end)
  end

  # === Activité ===

  @doc """
  Récupère le feed d'activité des amis.
  """
  def get_friend_activity(user_id, limit \\ 20) do
    user_id = to_integer(user_id)
    friend_ids = get_accepted_friend_ids(user_id)

    query = from a in FriendActivity,
      where: a.user_id in ^friend_ids,
      order_by: [desc: a.inserted_at],
      limit: ^limit

    Repo.all(query)
    |> Enum.map(fn a ->
      case Repo.get(User, a.user_id) do
        nil -> %{activity: a, user: %{id: a.user_id, name: "Inconnu"}}
        user -> %{activity: a, user: %{id: user.id, name: user.name}}
      end
    end)
  end

  @doc """
  Enregistre une activité pour un utilisateur.
  """
  def record_activity(user_id, action, metadata \\ %{}) do
    user_id = to_integer(user_id)

    %FriendActivity{}
    |> FriendActivity.create_changeset(%{user_id: user_id, action: action, metadata: metadata})
    |> Repo.insert()
    |> case do
      {:ok, activity} ->
        # Notifier les amis
        broadcast_activity(user_id, action, metadata)
        {:ok, activity}
      error -> error
    end
  end

  # === Messages ===

  @doc """
  Envoie un message à un ami.
  """
  def send_message(sender_id, receiver_id, content, emoji_type \\ nil) do
    sender_id = to_integer(sender_id)
    receiver_id = to_integer(receiver_id)

    %FriendMessage{}
    |> FriendMessage.create_changeset(%{
      sender_id: sender_id,
      receiver_id: receiver_id,
      content: content,
      emoji_type: emoji_type
    })
    |> Repo.insert()
    |> case do
      {:ok, message} ->
        # Notifier via PubSub
        Phoenix.PubSub.broadcast(
          GameHub.PubSub,
          "user:#{receiver_id}:friends",
          %{event: "chat_message", payload: %{from_user_id: sender_id, content: content, emoji_type: emoji_type}}
        )
        {:ok, message}
      error -> error
    end
  end

  @doc """
  Récupère les messages entre deux utilisateurs.
  """
  def get_conversation(user_id, friend_id, limit \\ 50) do
    user_id = to_integer(user_id)
    friend_id = to_integer(friend_id)

    query = from m in FriendMessage,
      where: (m.sender_id == ^user_id and m.receiver_id == ^friend_id) or
             (m.sender_id == ^friend_id and m.receiver_id == ^user_id),
      order_by: [desc: m.inserted_at],
      limit: ^limit

    Repo.all(query)
  end

  @doc """
  Compte les demandes en attente.
  """
  def count_pending_requests(user_id) do
    user_id = to_integer(user_id)

    Repo.one(
      from f in Friendship,
        where: f.friend_id == ^user_id and f.status == "pending",
        select: count(f.id)
    )
  end

  # === Helpers Privés ===

  defp get_accepted_friend_ids(user_id) do
    user_id = to_integer(user_id)

    friendships = Repo.all(
      from f in Friendship,
        where: f.status == "accepted" and (f.user_id == ^user_id or f.friend_id == ^user_id)
    )

    Enum.map(friendships, fn f ->
      if f.user_id == user_id, do: f.friend_id, else: f.user_id
    end)
  end

  defp get_online_status(_user_id) do
    # TODO: Intégrer avec la présence Phoenix
    "offline"
  end

  defp notify_friend(user_id, event, payload) do
    Phoenix.PubSub.broadcast(
      GameHub.PubSub,
      "user:#{user_id}:friends",
      %{event: event, payload: payload}
    )
  rescue
    _ -> :ok
  end

  defp broadcast_activity(user_id, action, metadata) do
    Phoenix.PubSub.broadcast(
      GameHub.PubSub,
      "friends:activity",
      %{event: "activity_update", payload: %{user_id: user_id, action: action, metadata: metadata}}
    )
  rescue
    _ -> :ok
  end

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(val) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> val
    end
  end
  defp to_integer(val), do: val
end
