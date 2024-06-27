defmodule F1Bot.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    if F1Bot.demo_mode?() do
      Logger.info("[DEMO] Starting in demo mode with url: #{F1Bot.demo_mode_url()}")
    end

    start_if_feature_flag_enabled(:start_discord, :nostrum)

    children =
      [
        {Finch, name: F1Bot.Finch},
        {DynamicSupervisor, name: F1Bot.DynamicSupervisor, strategy: :one_for_one},
        F1BotWeb.Telemetry,
        F1Bot.Repo,
        {Phoenix.PubSub, name: F1Bot.PubSub},
        F1Bot.DelayedEvents.Supervisor,
        F1Bot.Output.Discord,
        F1Bot.F1Session.Server,
        F1BotWeb.Supervisor,
        F1Bot.Replay.Server,
        F1Bot.TranscriberService
      ]
      |> add_if_feature_flag_enabled(:connect_to_signalr, {
        F1Bot.ExternalApi.SignalR.Client,
        [
          scheme: "https",
          hostname: "livetiming.formula1.com",
          base_path: "/signalr",
          user_agent: "",
          port: 443,
          hub: "Streaming",
          topics:
            case F1Bot.fetch_env(:signalr_topics) do
              {:ok, topics} -> topics
            end
        ]
      })
      |> add_if_feature_flag_enabled(:start_discord, F1Bot.ExternalApi.Discord.Commands)
      |> add_if_feature_flag_enabled(:auto_reload_session, {
        Task,
        fn -> F1Bot.reload_session(true) end
      })
      |> add_if_demo_mode_enabled(F1Bot.Demo.Supervisor)

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

  defp start_if_feature_flag_enabled(feature_flag, application) do
    if feature_flag_enabled?(feature_flag) do
      {:ok, _} = Application.ensure_all_started(application)
    end
  end

  defp add_if_feature_flag_enabled(children, feature_flag, child) do
    if feature_flag_enabled?(feature_flag) and not F1Bot.demo_mode?() do
      children ++ [child]
    else
      children
    end
  end

  defp add_if_demo_mode_enabled(children, child) do
    if F1Bot.demo_mode?() do
      children ++ [child]
    else
      children
    end
  end

  defp feature_flag_enabled?(feature_flag) do
    F1Bot.get_env(feature_flag, false)
  end
end
