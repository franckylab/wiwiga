# ==================================
# WIWIGA - Tâche re-chiffrement providers
# ==================================
# Usage: mix notifications.reencrypt_providers
# Étape 3 de la rotation de clé (voir ConfigCrypto).

defmodule Mix.Tasks.Notifications.ReencryptProviders do
  @moduledoc """
  Re-chiffre les configs providers avec la clé primaire courante.

  À lancer après rotation de `NOTIFICATION_CONFIG_KEY`
  (ancienne clé conservée dans `NOTIFICATION_CONFIG_PREVIOUS_KEYS`).
  """

  use Mix.Task

  @shortdoc "Re-chiffre les secrets providers avec la clé primaire"

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    alias GameHub.Notifications
    alias GameHub.Notifications.{ConfigCrypto, Provider}
    alias GameHub.Repo

    providers = Repo.all(Provider)

    {rotated, skipped} =
      Enum.reduce(providers, {0, 0}, fn provider, {rotated, skipped} ->
        config = provider.config || %{}
        needs_rotation? = Enum.any?(config, fn {_key, value} ->
          is_binary(value) and ConfigCrypto.encrypted?(value) and not ConfigCrypto.primary_decryptable?(value)
        end)

        if needs_rotation? do
          case Notifications.update_provider(provider.id, %{"config" => ConfigCrypto.decrypt_config(config)}) do
            {:ok, _} -> {rotated + 1, skipped}
            {:error, reason} ->
              Mix.shell().error("Provider #{provider.id} : #{inspect(reason)}")
              {rotated, skipped + 1}
          end
        else
          {rotated, skipped + 1}
        end
      end)

    Mix.shell().info("Re-chiffrement terminé : #{rotated} rotés, #{skipped} inchangés.")
  end
end
