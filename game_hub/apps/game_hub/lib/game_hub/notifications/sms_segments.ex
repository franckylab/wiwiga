# ==================================
# WIWIGA - Segments SMS (GSM-7 vs Unicode)
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.SmsSegments
# Description: Comptage de segments pour maîtriser le coût
#              (1 SMS = 1 segment ; au-delà, facturation multiple).

defmodule GameHub.Notifications.SmsSegments do
  @moduledoc """
  Comptage de segments SMS.

  - GSM-7 : 160 caractères (153 en concaténé).
  - Unicode (UCS-2, ex. accents hors GSM, emojis) : 70 (67 en concaténé).
  """

  # Sous-ensemble GSM-7 de base suffisant pour la détection (ASCII
  # imprimable + quelques extensions courantes).
  @gsm_basic MapSet.new(
               Enum.to_list(?\s..?~) ++
                 [?\n, ?\r, ?\t, ?@, ?£, ?$, ?¥, ?è, ?é, ?ù, ?ì, ?ò, ?Ç, ?Ø, ?ø, ?Å, ?å, ?Æ, ?æ, ?ß, ?É, ?Ä, ?Ö, ?Ñ, ?Ü, ?§, ?¿, ?¡, ?¤, ?Þ, ?þ]
             )

  @doc """
  Compte les segments d'un texte : `%{encoding, chars, per_segment, segments}`.
  """
  @spec count(String.t()) :: %{encoding: String.t(), chars: non_neg_integer(), per_segment: pos_integer(), segments: pos_integer()}
  def count(text) when is_binary(text) do
    chars = String.length(text)
    gsm? = text |> String.to_charlist() |> Enum.all?(&MapSet.member?(@gsm_basic, &1))

    {encoding, single, concat} =
      if gsm?, do: {"gsm-7", 160, 153}, else: {"unicode", 70, 67}

    per_segment = if chars <= single, do: single, else: concat
    segments = max(1, ceil(chars / per_segment))

    %{encoding: encoding, chars: chars, per_segment: per_segment, segments: segments}
  end

  def count(_), do: %{encoding: "gsm-7", chars: 0, per_segment: 160, segments: 1}
end
