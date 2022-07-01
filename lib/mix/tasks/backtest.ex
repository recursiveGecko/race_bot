# credo:disable-for-this-file Credo.Check.Warning.IoInspect
defmodule Mix.Tasks.Backtest do
  @moduledoc """
  Downloads archives of previous races and runs an offline backtest which prints all
  Twitter and Discord messages to console.

  Usage:
  ```
  iex -S mix backtest --url "http://livetiming.formula1.com/static/2022/2022-05-08_Miami_Grand_Prix/2022-05-08_Race"
  ```
  """

  use Mix.Task
  require Config
  require Logger

  @impl Mix.Task
  def run(argv) do
    configure()

    parsed_args = parse_argv(argv)
    url = Keyword.fetch!(parsed_args, :url)

    Logger.info("Downloading & parsing dataset.")

    replay_options = %{
      exclude_files_regex: ~r/\.z\./,
      events_fn: &F1Bot.F1Session.Common.Helpers.publish_events/1,
      report_progress: true
    }

    {:ok, session} = F1Bot.Replay.session_from_url(url, replay_options)
    F1Bot.F1Session.Server.replace_session(session)

    Logger.info("Creating lap time graph.")

    # F1Bot.Plotting.plot_gap([16, 1], style: :lines) |> IO.inspect()
    # F1Bot.Plotting.plot_lap_times([16, 1], style: :lines, x_axis: :timestamp) |> IO.inspect()
    # F1Bot.Plotting.plot_lap_times([16, 1], style: :lines, x_axis: :timestamp) |> IO.inspect()
    # F1Bot.Plotting.plot_lap_times([16, 1], style: :lines) |> IO.inspect()

    total_mem_mb = (:erlang.memory(:total) / 1024 / 1024) |> round()
    Logger.info("Total memory usage: #{total_mem_mb} MB")
  end

  def parse_argv(argv) do
    {parsed_args, _, _} =
      OptionParser.parse(argv,
        strict: [
          url: :string
        ]
      )

    parsed_args
  end

  def configure() do
    Application.put_env(:gnuplot, :timeout, {3000, :ms})
    Application.put_env(:f1_bot, :connect_to_signalr, false)
    Application.put_env(:f1_bot, :external_apis_enabled, false)
    Application.put_env(:f1_bot, :discord_api_module, F1Bot.ExternalApi.Discord.Console)
    Application.put_env(:f1_bot, :twitter_api_module, F1Bot.ExternalApi.Twitter.Console)
    Application.put_env(:f1_bot, :extwitter_config, [])

    Finch.start_link(name: __MODULE__)
    {:ok, _} = Application.ensure_all_started(:f1_bot)
  end
end
