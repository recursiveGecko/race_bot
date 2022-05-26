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

  alias F1Bot.LiveTimingHandlers.Event

  @files [
    "TrackStatus.jsonStream",
    "RaceControlMessages.jsonStream",
    "SessionInfo.jsonStream",
    "SessionStatus.jsonStream",
    "TimingAppData.jsonStream",
    "TimingData.jsonStream",
    "DriverList.jsonStream",
    "WeatherData.jsonStream",
    "CarData.z.jsonStream",
    "Position.z.jsonStream",
    "Heartbeat.jsonStream"
  ]

  @impl Mix.Task
  def run(argv) do
    configure()

    parsed_args = parse_argv(argv)
    url = Keyword.fetch!(parsed_args, :url)

    Logger.info("Downloading & parsing dataset.")

    dataset =
      download_dataset(url)
      |> List.flatten()
      |> Enum.sort_by(fn {ts_ms, _f, _ts, _c} -> ts_ms end)

    base_ts = fetch_base_time(url)

    Logger.info("Replaying dataset.")
    total = length(dataset)
    replay_dataset(dataset, 0, total, base_ts)

    Logger.info("Creating lap time graph.")

    # F1Bot.Plotting.plot_gap([16, 1], style: :lines) |> IO.inspect()
    F1Bot.Plotting.plot_lap_times([16, 1], style: :lines, x_axis: :timestamp) |> IO.inspect()
    F1Bot.Plotting.plot_lap_times([16, 1], style: :lines) |> IO.inspect()

    F1Bot.session_info()
    |> IO.inspect()

    total_mem_mb = (:erlang.memory(:total) / 1024 / 1024) |> round()
    Logger.info("Total memory usage: #{total_mem_mb} MB")
  end

  def replay_dataset(
        [{_ts_ms, file_name, session_ts, payload} | rest],
        count,
        total,
        base_ts
      ) do
    if rem(count, 5000) == 0 do
      percent = round(count / total * 100)
      Logger.info("Replay status: #{count}/#{total} (#{percent} %)")
    end

    [topic | _] = String.split(file_name, ".")

    # Re-synchronize time
    base_ts =
      if topic == "Heartbeat" do
        base_ts = calculate_base_time(session_ts, payload["Utc"])

        # Logger.debug("Time synchronization: #{Timex.Duration.to_string(timestamp)} = #{payload["Utc"]}")
        base_ts
      else
        base_ts
      end

    timestamp = Timex.add(base_ts, session_ts)

    event = %Event{
      topic: topic,
      data: payload,
      timestamp: timestamp
    }

    F1Bot.LiveTimingHandlers.process_live_timing_event(event)

    replay_dataset(rest, count + 1, total, base_ts)
  end

  def replay_dataset([], _count, _total, _ts_offset) do
    Logger.info("Replay completed.")
  end

  def download_dataset(base_url) do
    @files
    |> Enum.map(fn f -> {f, download_file(base_url, f)} end)
    |> Enum.map(fn {f, c} -> parse_file(f, c) end)
  end

  def fetch_base_time(base_url) do
    {session_ts, json} =
      base_url
      |> download_file("Heartbeat.jsonStream")
      |> base_parse_file()
      |> List.last()
      |> IO.inspect()

    {:ok, session_ts} = F1Bot.DataTransform.Parse.parse_session_time(session_ts)
    data = Jason.decode!(json)

    calculate_base_time(session_ts, data["Utc"])
  end

  def calculate_base_time(session_ts = %Timex.Duration{}, utc_string)
      when is_binary(utc_string) do
    wall_ts = F1Bot.DataTransform.Parse.parse_iso_timestamp(utc_string)
    Timex.subtract(wall_ts, session_ts)
  end

  def download_file(base_url, file_name) do
    full_url = base_url <> "/" <> file_name

    {:ok, %{status: 200, body: body}} =
      Finch.build(:get, full_url)
      |> Finch.request(__MODULE__)

    body
  end

  def parse_file(file_name, contents) do
    contents
    |> base_parse_file()
    |> Enum.map(fn {timestamp, json} ->
      {:ok, session_ts} = F1Bot.DataTransform.Parse.parse_session_time(timestamp)
      ts_ms = session_ts |> Timex.Duration.to_milliseconds() |> round()

      data = Jason.decode!(json)
      {ts_ms, file_name, session_ts, data}
    end)
  end

  def base_parse_file(contents) do
    contents
    |> String.trim_leading("\uFEFF")
    |> String.split("\r\n")
    |> Enum.reject(fn x -> String.length(x) < 10 end)
    |> Enum.map(fn x -> String.split_at(x, 12) end)
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
