# ==================================
# WIWIGA - Schema Friend Message
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Friends.FriendMessage
# Description: Schema Ecto pour messages entre amis

defmodule GameHub.Friends.FriendMessage do
  @moduledoc """
  Schema des messages entre amis.
  Supporte texte court et emojis rapides.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :sender_id, :receiver_id, :content, :emoji_type, :read_at, :inserted_at]}

  schema "friend_messages" do
    field :sender_id, :integer
    field :receiver_id, :integer
    field :content, :string
    field :emoji_type, :string
    field :read_at, :utc_datetime

    timestamps()
  end

  def create_changeset(message, attrs) do
    message
    |> cast(attrs, [:sender_id, :receiver_id, :content, :emoji_type])
    |> validate_required([:sender_id, :receiver_id])
    |> validate_content_or_emoji()
  end

  def mark_read_changeset(message) do
    message
    |> change(%{read_at: DateTime.utc_now()})
  end

  defp validate_content_or_emoji(changeset) do
    content = get_field(changeset, :content)
    emoji = get_field(changeset, :emoji_type)

    cond do
      is_nil(content) and is_nil(emoji) ->
        add_error(changeset, :content, "content ou emoji_type est requis")

      true ->
        changeset
    end
  end
end
