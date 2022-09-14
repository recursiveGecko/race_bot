defmodule F1Bot.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    if F1Bot.demo_mode_url() != nil do
      Logger.info("[DEMO] Starting in demo mode with url: #{F1Bot.demo_mode_url()}")
    end

    maybe_start_external_api_apps()

    children =
      [
        # Start the Ecto repository
        F1Bot.Repo,
        F1Bot.Cache,
        # Start the Telemetry supervisor
        F1BotWeb.Telemetry,
        # Start the PubSub system
        {Phoenix.PubSub, name: F1Bot.PubSub},
        # Start the Endpoint (http/https)
        F1BotWeb.Endpoint,
        {Finch, name: F1Bot.Finch},
        F1Bot.Output.Discord,
        F1Bot.Output.Twitter,
        F1Bot.F1Session.Server,
        F1Bot.Replay.Server
      ]
      |> add_if_signalr_conn_enabled({
        F1Bot.ExternalApi.SignalR.Client,
        [
          hostname: "livetiming.formula1.com",
          path: "/signalr",
          port: 80,
          hub: "Streaming",
          topics:
            case F1Bot.fetch_env(:signalr_topics) do
              {:ok, topics} -> topics
            end
        ]
      })
      |> add_if_external_apis_enabled(F1Bot.ExternalApi.Discord.Live)
      |> add_if_external_apis_enabled(F1Bot.ExternalApi.Twitter.Live)
      |> add_if_external_apis_enabled(F1Bot.ExternalApi.Discord.Commands)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [
      strategy: :one_for_one,
      max_restarts: 1000,
      name: F1Bot.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    F1BotWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_start_external_api_apps() do
    if external_apis_enabled?() do
      {:ok, _} = Application.ensure_all_started(:nostrum)
    end
  end

  defp add_if_external_apis_enabled(children, child) do
    if external_apis_enabled?() and F1Bot.demo_mode_url() == nil do
      children ++ [child]
    else
      children
    end
  end

  defp add_if_signalr_conn_enabled(children, child) do
    if signalr_enabled?() and F1Bot.demo_mode_url() == nil do
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
