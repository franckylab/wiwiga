# ==================================
# WIWIGA - Chiffrement des secrets providers
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.ConfigCrypto
# Description: AES-256-GCM via :crypto. Seules les valeurs sensibles
#              (api_key, secret, token, password...) sont chiffrées,
#              le reste de la config reste en clair et requêtable.

defmodule GameHub.Notifications.ConfigCrypto do
  @moduledoc """
  Chiffrement enveloppe des secrets de configuration providers.

  ## Clés
  - `NOTIFICATION_CONFIG_KEY` : clé primaire (32 octets base64).
  - `NOTIFICATION_CONFIG_PREVIOUS_KEYS` : anciennes clés séparées par
    des virgules, conservées pour le déchiffrement après rotation.
  - En dev/test : clé dérivée fixe (jamais en prod).

  ## Rotation (sans interruption)
  1. Ajouter l'ancienne clé à `NOTIFICATION_CONFIG_PREVIOUS_KEYS`.
  2. Générer une nouvelle clé (`openssl rand -base64 32`) dans
     `NOTIFICATION_CONFIG_KEY` et redémarrer.
  3. Lancer `mix notifications.reencrypt_providers` (re-chiffre tout
     avec la clé primaire).
  4. Retirer l'ancienne clé des précédentes au cycle suivant.

  ## Format
  `"v1.<iv_b64>.<cipher_tag_b64>"`.
  """

  @envelope_version "v1"
  @sensitive_pattern ~r/password|secret|api[_-]?key|token|private|passwd/i

  @doc """
  Retourne true si une clé de config est sensible.
  """
  @spec sensitive_key?(String.t()) :: boolean()
  def sensitive_key?(key) when is_binary(key), do: Regex.match?(@sensitive_pattern, key)
  def sensitive_key?(_), do: false

  @doc """
  Chiffre une config : les valeurs sensibles sont enveloppées.
  `extra_sensitive` : clés sensibles imposées par le schéma provider
  (ex. `auth_header`), en plus de l'heuristique de nom.
  """
  @spec encrypt_config(map(), list(String.t())) :: map()
  def encrypt_config(config, extra_sensitive \\ [])

  def encrypt_config(config, extra_sensitive) when is_map(config) and is_list(extra_sensitive) do
    forced = MapSet.new(Enum.map(extra_sensitive, &to_string/1))

    Map.new(config, fn {key, value} ->
      string_key = to_string(key)
      sensitive? = sensitive_key?(string_key) or MapSet.member?(forced, string_key)

      if sensitive? and is_binary(value) and value != "" and not encrypted?(value) do
        {string_key, encrypt_value(value)}
      else
        {string_key, value}
      end
    end)
  end

  def encrypt_config(_, _), do: %{}

  @doc """
  Déchiffre une config (enveloppes `v1.*`, le reste inchangé).
  N'échoue jamais : valeur illisible → chaîne vide.
  """
  @spec decrypt_config(map()) :: map()
  def decrypt_config(config) when is_map(config) do
    Map.new(config, fn {key, value} ->
      string_key = to_string(key)

      if is_binary(value) and encrypted?(value) do
        {string_key, decrypt_value(value)}
      else
        {string_key, value}
      end
    end)
  end

  def decrypt_config(_), do: %{}

  @doc """
  Retourne true si la valeur est une enveloppe chiffrée.
  """
  @spec encrypted?(String.t()) :: boolean()
  def encrypted?(@envelope_version <> "." <> rest) when is_binary(rest) do
    case String.split(rest, ".") do
      [_iv, _cipher] -> true
      _ -> false
    end
  end

  def encrypted?(_), do: false

  @doc """
  Retourne true si une enveloppe se déchiffre avec la clé primaire.
  Sert à détecter les configs à re-chiffrer après rotation.
  """
  @spec primary_decryptable?(String.t()) :: boolean()
  def primary_decryptable?(envelope) when is_binary(envelope) do
    case split_envelope(envelope) do
      {:ok, iv, cipher, tag} -> try_decrypt(primary_key(), iv, cipher, tag) != :error
      :error -> false
    end
  end

  def primary_decryptable?(_), do: false

  # === Privé ===

  defp encrypt_value(plaintext) do
    key = encryption_key()
    iv = :crypto.strong_rand_bytes(12)
    {cipher, tag} = :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, plaintext, "", true)
    "#{@envelope_version}.#{Base.encode64(iv)}.#{Base.encode64(cipher <> tag)}"
  end

  defp decrypt_value(envelope) do
    case split_envelope(envelope) do
      {:ok, iv, cipher, tag} ->
        Enum.find_value(encryption_keys(), "", fn key ->
          case try_decrypt(key, iv, cipher, tag) do
            :error -> nil
            plaintext -> plaintext
          end
        end)

      :error ->
        ""
    end
  rescue
    _ -> ""
  catch
    _, _ -> ""
  end

  defp split_envelope(envelope) when is_binary(envelope) do
    case String.split(envelope, ".") do
      [@envelope_version, iv_b64, cipher_b64] ->
        with {:ok, iv} <- Base.decode64(iv_b64),
             {:ok, cipher_tag} <- Base.decode64(cipher_b64),
             true <- byte_size(cipher_tag) > 16 do
          cipher_size = byte_size(cipher_tag) - 16
          <<cipher::binary-size(cipher_size), tag::binary-16>> = cipher_tag
          {:ok, iv, cipher, tag}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp split_envelope(_), do: :error

  defp try_decrypt(key, iv, cipher, tag) do
    :crypto.crypto_one_time_aead(:aes_256_gcm, key, iv, cipher, "", tag, false)
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end

  # Clé primaire d'abord, puis les précédentes (rotation).
  defp encryption_keys do
    [primary_key() | previous_keys()] |> Enum.uniq()
  end

  defp encryption_key, do: primary_key()

  defp primary_key do
    case System.get_env("NOTIFICATION_CONFIG_KEY") do
      nil -> dev_key()
      "" -> dev_key()
      b64 -> decode_or_dev(b64)
    end
  end

  defp previous_keys do
    System.get_env("NOTIFICATION_CONFIG_PREVIOUS_KEYS", "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn b64 ->
      case Base.decode64(b64) do
        {:ok, <<key::binary-32>>} -> [key]
        _ -> []
      end
    end)
  end

  defp decode_or_dev(b64) do
    case Base.decode64(String.trim(b64)) do
      {:ok, <<key::binary-32>>} -> key
      _ -> dev_key()
    end
  end

  # Clé dev/test uniquement — la prod exige NOTIFICATION_CONFIG_KEY
  # (vérifié au boot par GameHub.EnvConfig.validate_production!/0, voir Phase 2).
  defp dev_key do
    :crypto.hash(:sha256, "wiwiga-dev-notification-config-key-v1")
  end
end
