# ==================================
# WIWIGA - Télémétrie notifications
# ==================================
# Auteur: Franck Arlos CHENDJOU
# Module: GameHub.Notifications.Telemetry
# Description: Événements `:telemetry` (compteurs + statuts).
#              À brancher sur Prometheus/Grafana via TelemetryMetrics
#              (voir runbook § Métriques). Émission best-effort.

defmodule GameHub.Notifications.Telemetry do
  @moduledoc """
  Événements émis (jamais bloquants, jamais d'exception) :

  - `[:wiwiga, :notifications, :dispatch]` — `%{count: 1}`,
    meta `%{event_type, category, channels}`
  - `[:wiwiga, :notifications, :delivery]` — `%{count: 1}`,
    meta `%{channel, status, provider}`
  - `[:wiwiga, :notifications, :broadcast_batch]` — `%{sent: n}`,
    meta `%{event_id, category}`
  """

  @doc """
  Émet un événement (no-op silencieux en cas d'échec).
  """
  @spec emit(list(atom()), map(), map()) :: :ok
  def emit(event, measurements, metadata) do
    :telemetry.execute([:wiwiga, :notifications] ++ event, measurements, metadata)
  rescue
    _ -> :ok
  catch
    _, _ -> :ok
  end

  @doc """
  Attache un handler (ex. tests, reporters).
  """
  @spec attach_many(term(), list(list(atom())), function()) :: :ok | {:error, term()}
  def attach_many(handler_id, events, handler) do
    full = Enum.map(events, fn event -> [:wiwiga, :notifications] ++ event end)
    :telemetry.attach_many(handler_id, full, handler, nil)
  end

  @doc """
  Détache un handler.
  """
  @spec detach(term()) :: :ok | {:error, term()}
  def detach(handler_id) do
    :telemetry.detach(handler_id)
  end
end
