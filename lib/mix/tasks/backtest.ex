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

  alias F1Bot.Replay
  alias F1Bot.F1Session.LiveTimingHandlers.ProcessingOptions

  @impl Mix.Task
  def run(argv) do
    configure()

    parsed_args = parse_argv(argv)
    url = Keyword.fetch!(parsed_args, :url)

    Logger.info("Downloading & parsing dataset.")

    replay_options = %Replay.Options{
      exclude_files_regex: ~r/\.z\./,
      # Broadcast events on the PubSub bus, this allows us to quickly review
      # the sanity of F1 packet processing logic by inspecting the console output
      # for simulated Discord and Twitter messages.
      events_fn: &F1Bot.PubSub.broadcast_events/1,
      report_progress: true,
      processing_options: %ProcessingOptions{
        skip_heavy_events: false
      }
    }

    # profile_start()
    {:ok, %{session: session}} = Replay.start_replay(url, replay_options)
    # profile_end()

    F1Bot.F1Session.Server.replace_session(session)

    total_mem_mb = (:erlang.memory(:total) / 1024 / 1024) |> round()
    Logger.info("Total memory usage: #{total_mem_mb} MB")
  end

  def profile_start() do
    :eprof.start_profiling([self()])
  end

  def profile_end() do
    :eprof.stop_profiling()
    :eprof.analyze()
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
