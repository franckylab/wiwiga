# ==================================
# WIWIGA - Module Validators
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Validators
# Description: Validation et sanitisation des inputs (Règle 5)

defmodule GameHub.Validators do
  @moduledoc """
  Module de validation des inputs.
  
  Règle 5 : TOUJOURS valider ET sanitiser AVANT traitement.
  
  Validations obligatoires :
  - Montants financiers
  - Numéros de téléphone
  - Messages de chat
  - IDs de ressource
  """
  
  @doc """
  Valide un montant de pari.
  
  ## Parameters
    - `amount`: Montant à valider
  
  ## Returns
    - `:ok`: Montant valide
    - `{:error, reason}`: Montant invalide
  
  ## Examples
  
      iex> Validators.validate_bet_amount(5000)
      :ok
      
      iex> Validators.validate_bet_amount(-100)
      {:error, "Montant doit être positif"}
  """
  @spec validate_bet_amount(integer()) :: :ok | {:error, String.t()}
  def validate_bet_amount(amount) do
    cond do
      not is_integer(amount) ->
        {:error, "Montant doit être entier"}
      
      amount <= 0 ->
        {:error, "Montant doit être positif"}
      
      amount > 1_000_000_000 ->
        {:error, "Excède mise maximale (1 milliard FCFA)"}
      
      true ->
        :ok
    end
  end
  
  @doc """
  Valide un numéro de téléphone camerounais.
  
  ## Parameters
    - `phone`: Numéro à valider
  
  ## Returns
    - `:ok`: Numéro valide
    - `{:error, reason}`: Numéro invalide
  
  ## Examples
  
      iex> Validators.validate_phone("+237612345678")
      :ok
      
      iex> Validators.validate_phone("123456")
      {:error, "Numéro de téléphone invalide"}
  """
  @spec validate_phone(String.t()) :: :ok | {:error, String.t()}
  def validate_phone("+237" <> rest) when byte_size(rest) == 9 do
    case Regex.match?(~r/^[67][0-9]{8}$/, rest) do
      true -> :ok
      false -> {:error, "Numéro de téléphone invalide"}
    end
  end
  
  def validate_phone(_phone) do
    {:error, "Numéro doit commencer par +237 et avoir 9 chiffres"}
  end
  
  @doc """
  Sanitize un message de chat (prévention XSS).
  
  ## Parameters
    - `message`: Message à sanitiser
  
  ## Returns
    - `message`: Message sanitisé
  
  ## Examples
  
      iex> Validators.sanitize_chat_message("<script>alert('xss')</script>Hello")
      "alert('xss')Hello"
  """
  @spec sanitize_chat_message(String.t()) :: String.t()
  def sanitize_chat_message(message) do
    message
    |> String.replace(~r/<[^>]*>/, "")  # Strip HTML tags
    |> String.slice(0, 500)  # Max 500 caractères
    |> String.trim()
  end
  
  @doc """
  Valide un ID de ressource.
  
  ## Parameters
    - `id`: ID à valider
  
  ## Returns
    - `:ok`: ID valide
    - `{:error, reason}`: ID invalide
  """
  @spec validate_resource_id(String.t() | integer()) :: :ok | {:error, String.t()}
  def validate_resource_id(id) when is_integer(id) and id > 0, do: :ok
  def validate_resource_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} when int > 0 -> :ok
      _ -> {:error, "ID de ressource invalide"}
    end
  end
  def validate_resource_id(_), do: {:error, "ID de ressource invalide"}
  
  @doc """
  Valide les paramètres de dépôt.
  
  ## Parameters
    - `params`: Paramètres à valider
  
  ## Returns
    - `{:ok, validated_params}`: Paramètres validés
    - `{:error, errors}`: Erreurs de validation
  """
  @spec validate_deposit_params(map()) :: {:ok, map()} | {:error, list()}
  def validate_deposit_params(%{"amount" => amount, "idempotency_key" => key}) do
    errors = []
    
    errors = case validate_bet_amount(amount) do
      :ok -> errors
      {:error, reason} -> ["amount: #{reason}" | errors]
    end
    
    errors = if is_binary(key) and byte_size(key) > 0 do
      errors
    else
      ["idempotency_key: Clé d'idempotence requise" | errors]
    end
    
    if length(errors) == 0 do
      {:ok, %{"amount" => amount, "idempotency_key" => key}}
    else
      {:error, Enum.reverse(errors)}
    end
  end
  
  def validate_deposit_params(_) do
    {:error, ["Paramètres 'amount' et 'idempotency_key' requis"]}
  end
  
  @doc """
  Valide un montant de retrait.
  
  ## Parameters
    - `amount`: Montant
    - `balance`: Solde actuel
  
  ## Returns
    - `:ok`: Montant valide
    - `{:error, reason}`: Montant invalide
  """
  @spec validate_withdrawal_amount(integer(), integer()) :: :ok | {:error, String.t()}
  def validate_withdrawal_amount(amount, balance) do
    cond do
      amount < 100 ->
        {:error, "Montant minimum: 100 FCFA"}
      
      amount > balance ->
        {:error, "Solde insuffisant"}
      
      true ->
        :ok
    end
  end
end
