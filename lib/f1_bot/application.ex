defmodule F1Bot.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    maybe_start_external_api_apps()

    children =
      [
        # Starts a worker by calling: F1Bot.Worker.start_link(arg)
        # {F1Bot.Worker, arg}
        {Finch, name: F1Bot.Finch},
        {Phoenix.PubSub, name: :f1_pubsub},
        F1Bot.Output.Discord,
        F1Bot.Output.Twitter,
        F1Bot.F1Session.Server,
        F1Bot.LiveTimingHandlers
      ]
      |> add_if_signalr_conn_enabled({
        F1Bot.ExternalApi.SignalR.Client,
        [
          hostname: "livetiming.formula1.com",
          path: "/signalr",
          port: 80,
          hub: "Streaming",
          topics: [
            "TrackStatus",
            "TeamRadio",
            "RaceControlMessages",
            "SessionInfo",
            "SessionStatus",
            "TimingAppData",
            "TimingData",
            "DriverList",
            "WeatherData",
            # Car telemetry
            "CarData.z",
            # Car position (GPS)
            "Position.z"
            # Session time remaining and real time clock sync
            # "ExtrapolatedClock",
            #  "AudioStreams",
          ]
        ]
      })
      |> add_if_external_apis_enabled(F1Bot.ExternalApi.Discord.Live)
      |> add_if_external_apis_enabled(F1Bot.ExternalApi.Twitter.Live)
      |> add_if_external_apis_enabled(F1Bot.ExternalApi.Discord.ApplicationCommands)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_one,
      max_restarts: 1000,
      name: F1Bot.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  defp maybe_start_external_api_apps() do
    if external_apis_enabled?() do
      {:ok, _} = Application.ensure_all_started(:nostrum)
    end
  end

  defp add_if_external_apis_enabled(children, child) do
    if external_apis_enabled?() do
      children ++ [child]
    else
      children
    end
  end

  defp add_if_signalr_conn_enabled(children, child) do
    if signalr_enabled?() do
      children ++ [child]
    else
      children
    end
  end

  defp external_apis_enabled?() do
    F1Bot.get_env(:external_apis_enabled, false)
  end

  defp signalr_enabled?() do
    F1Bot.get_env(:connect_to_signalr, false)
  end
end
