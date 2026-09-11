# ==================================
# WIWIGA - Schéma Template Notification
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Template

defmodule GameHub.Notifications.Template do
  @moduledoc """
  Schéma des templates de notification versionnés.

  ## Clés d'événements (template_key)
    - `otp_login` : code OTP (sms, urgent)
    - `wallet_credit` / `wallet_debit` : mouvements de jetons
    - `match_result` : résultat de match
    - `friend_request` : demande d'ami
    - `promo_broadcast` : promotion marketing
    - `security_alert` : alerte sécurité
    - `admin_broadcast` : annonce admin

  Le corps utilise des variables `{{nom_variable}}` rendues
  par `GameHub.Notifications.TemplateRenderer`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :key,
             :channel,
             :locale,
             :version,
             :subject,
             :body_tpl,
             :required_variables,
             :category,
             :is_active,
             :default_priority,
             :action,
             :inserted_at
           ]}

  @channels ~w(in_app push sms email)
  @categories ~w(security transactional social game marketing)
  @priorities ~w(urgent high normal low)

  @primary_key {:id, :id, autogenerate: true}
  schema "notification_templates" do
    field :key, :string
    field :channel, :string
    field :locale, :string, default: "fr"
    field :version, :integer, default: 1
    field :subject, :string
    field :body_tpl, :string
    field :required_variables, {:array, :string}, default: []
    field :category, :string, default: "transactional"
    field :is_active, :boolean, default: true
    field :default_priority, :string, default: "normal"
    field :action, :string
    field :created_by, :integer

    timestamps()
  end

  @doc """
  Retourne les catégories supportées.
  """
  @spec categories() :: list(String.t())
  def categories, do: @categories

  @doc """
  Changeset de création/mise à jour d'un template.
  """
  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(template \\ %__MODULE__{}, attrs) do
    template
    |> cast(attrs, [
      :key,
      :channel,
      :locale,
      :version,
      :subject,
      :body_tpl,
      :required_variables,
      :category,
      :is_active,
      :default_priority,
      :action,
      :created_by
    ])
    |> validate_required([:key, :channel, :body_tpl])
    |> validate_inclusion(:channel, @channels)
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:default_priority, @priorities)
    |> validate_number(:version, greater_than: 0)
    |> unique_constraint([:key, :channel, :locale, :version])
  end
end
