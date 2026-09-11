# ==================================
# WIWIGA - Migration sujets email (marque en fin, ≤50 car.)
# ==================================
# Ne touche que les valeurs exactes des seeds précédents
# (personnalisations admin préservées).

defmodule GameHub.Repo.Migrations.UpdateEmailSubjects do
  use Ecto.Migration

  @mapping [
    {"otp_login", "[WIWIGA] Votre code : {{code}}", "Votre code : {{code}} — WIWIGA"},
    {"wallet_credit", "[WIWIGA] +{{montant}} jetons", "+{{montant}} jetons — WIWIGA"},
    {"wallet_debit", "[WIWIGA] -{{montant}} jetons", "-{{montant}} jetons — WIWIGA"},
    {"match_result", "[WIWIGA] {{resultat}}", "{{resultat}} — WIWIGA"},
    {"friend_request", "[WIWIGA] Demande d'ami", "Demande d'ami — WIWIGA"},
    {"security_alert", "[WIWIGA] Alerte sécurité", "Alerte sécurité — WIWIGA"},
    {"admin_broadcast", "[WIWIGA] {{titre}}", "{{titre}} — WIWIGA"},
    {"promo_broadcast", "[WIWIGA] {{titre}}", "{{titre}} — WIWIGA"}
  ]

  def up do
    for {key, old_subject, new_subject} <- @mapping do
      execute(
        "UPDATE notification_templates SET subject = '#{escape(new_subject)}' " <>
          "WHERE channel = 'email' AND key = '#{key}' AND subject = '#{escape(old_subject)}'"
      )
    end
  end

  def down, do: :ok

  defp escape(value), do: String.replace(value, "'", "''")
end
