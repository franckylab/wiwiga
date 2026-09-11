# ==================================
# WIWIGA - Schéma Suppression (opt-out définitif)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Suppression
# Description: STOP SMS, hard bounce / plainte email.
#              Vérifié AVANT chaque envoi sms/email (sauf sécurité :
#              un STOP marketing ne bloque jamais un OTP — norme TCPA).

defmodule GameHub.Notifications.Suppression do
  @moduledoc """
  Liste de suppression centrale (single source of truth).

  ## Raisons
    - `stop_keyword` — STOP/QUIT/... reçu par SMS entrant
    - `hard_bounce` — bounce permanent SES
    - `complaint` — plainte spam SES
    - `manual` — ajout admin
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :channel, :value, :reason, :source, :expires_at, :inserted_at]}

  @channels ~w(sms email)
  @reasons ~w(stop_keyword hard_bounce complaint manual)

  @primary_key {:id, :id, autogenerate: true}
  schema "notification_suppressions" do
    field :channel, :string
    field :value, :string
    field :reason, :string
    field :source, :string
    field :expires_at, :utc_datetime

    timestamps(updated_at: false)
  end

  @doc """
  Changeset de création (valeur normalisée : minuscules, trimée).
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(suppression \\ %__MODULE__{}, attrs) do
    suppression
    |> cast(attrs, [:channel, :value, :reason, :source, :expires_at])
    |> update_change(:value, &normalize/1)
    |> validate_required([:channel, :value, :reason, :source])
    |> validate_inclusion(:channel, @channels)
    |> validate_inclusion(:reason, @reasons)
    |> unique_constraint([:channel, :value])
  end

  defp normalize(value) when is_binary(value) do
    value |> String.trim() |> String.downcase()
  end

  defp normalize(value), do: value
end
