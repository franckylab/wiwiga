# ==================================
# WIWIGA - Layout HTML des emails
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.EmailLayout
# Description: Enveloppe responsive mobile-first (table 600px,
#              CSS inline, fond sombre compatible dark mode),
#              pré-header, CTA, pied de page par catégorie.

defmodule GameHub.Notifications.EmailLayout do
  @moduledoc """
  Mise en page HTML des emails WIWIGA.

  Règles appliquées (best practices 2025-2026) :
  - Layout table une colonne, 600px max, CSS inline (compatibilité clients).
  - Police 16px+, bouton CTA 44px+ (mobile-first).
  - Pré-header = début du corps (aperçu boîte de réception).
  - Version texte conservée en parallèle (toujours envoyée aussi).
  - Marketing : mention désinscription + headers List-Unsubscribe
    (fournis par l'adapter, voir `unsubscribe_headers/2`).
  """

  @doc """
  Enveloppe un corps texte dans le layout brandé.

  ## Options
    - `:subject` — sujet (titre du header)
    - `:category` — security|transactional|social|game|marketing
    - `:app_url` — CTA "Ouvrir WIWIGA" (défaut https://wiwiga.com)
    - `:preferences_url` — lien gestion des préférences (marketing)
  """
  @spec wrap(String.t(), String.t(), keyword()) :: String.t()
  def wrap(subject, text_body, opts \\ []) do
    category = Keyword.get(opts, :category, "transactional") |> to_string()
    app_url = Keyword.get(opts, :app_url, "https://wiwiga.com") |> to_string()
    preferences_url = Keyword.get(opts, :preferences_url, "https://wiwiga.com/notifications/preferences") |> to_string()

    preheader = text_body |> to_string() |> String.slice(0, 100)
    paragraphs = text_body |> to_string() |> String.split(~r/\n\n+/) |> Enum.map(&paragraph/1) |> Enum.join("\n")

    """
    <!DOCTYPE html>
    <html lang="fr">
    <head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
    <body style="margin:0;padding:0;background-color:#0F172A;">
    <div style="display:none;max-height:0;overflow:hidden;opacity:0;">#{escape(preheader)}</div>
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0F172A;">
    <tr><td align="center" style="padding:24px 12px;">
    <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;background-color:#1E293B;border-radius:12px;border:1px solid #334155;">
    <tr><td style="padding:24px 24px 8px 24px;font-family:Arial,Helvetica,sans-serif;font-size:22px;font-weight:bold;color:#2DD4BF;">WIWIGA</td></tr>
    <tr><td style="padding:0 24px 8px 24px;font-family:Arial,Helvetica,sans-serif;font-size:18px;font-weight:bold;color:#F8FAFC;">#{escape(subject)}</td></tr>
    <tr><td style="padding:8px 24px;font-family:Arial,Helvetica,sans-serif;font-size:16px;line-height:1.6;color:#F8FAFC;">#{paragraphs}</td></tr>
    <tr><td align="center" style="padding:16px 24px;">
    <a href="#{escape(app_url)}" style="display:inline-block;background-color:#2DD4BF;color:#0F172A;font-family:Arial,Helvetica,sans-serif;font-size:16px;font-weight:bold;text-decoration:none;padding:14px 32px;border-radius:8px;">Ouvrir WIWIGA</a>
    </td></tr>
    <tr><td style="padding:8px 24px 24px 24px;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:#94A3B8;">#{footer(category, preferences_url)}</td></tr>
    </table>
    </td></tr>
    </table>
    </body>
    </html>
    """
  end

  @doc """
  Headers List-Unsubscribe (one-click) pour le marketing.
  Exigés par Gmail pour les expéditeurs en volume (2024+).
  """
  @spec unsubscribe_headers(String.t(), String.t()) :: list({String.t(), String.t()})
  def unsubscribe_headers(preferences_url, mailto \\ "unsubscribe@wiwiga.com") do
    [
      {"List-Unsubscribe", "<mailto:#{mailto}> <#{preferences_url}>"},
      {"List-Unsubscribe-Post", "List-Unsubscribe=One-Click"}
    ]
  end

  defp paragraph(text) do
    "<p style=\"margin:0 0 12px 0;\">#{escape(text)}</p>"
  end

  defp footer("marketing", preferences_url) do
    "Vous recevez ce message car les promotions sont activées. " <>
      "<a href=\"#{escape(preferences_url)}\" style=\"color:#2DD4BF;\">Se désinscrire ou gérer mes préférences</a>."
  end

  defp footer(_, _) do
    "Message automatique WIWIGA — merci de ne pas y répondre. " <>
      "Gérez vos notifications dans l'application (Notifications &gt; Préférences)."
  end

  defp escape(nil), do: ""

  defp escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
