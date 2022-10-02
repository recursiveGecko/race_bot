defmodule F1Bot.Replay do
  require Logger

  alias F1Bot.F1Session.LiveTimingHandlers.Packet
  alias F1Bot.F1Session.LiveTimingHandlers
  alias F1Bot.F1Session

  def start_replay(url, options \\ %{}) do
    if String.match?(url, ~r"^https?://livetiming.formula1.com/static/") do
      url = String.replace_trailing(url, "/", "")

      dataset =
        download_dataset(url, options)
        |> List.flatten()
        |> Enum.sort_by(fn {ts_ms, _f, _ts, _c} -> ts_ms end)

      base_ts = fetch_base_time(url, options)

      if !!options[:report_progress] do
        Logger.info("Replaying dataset.")
      end

      total = length(dataset)

      state = %{
        session: F1Session.new(),
        dataset: dataset,
        processed_packets: 0,
        total_packets: total,
        base_ts: base_ts
      }

      state = replay_dataset(state, options)

      {:ok, state}
    else
      {:error, :invalid_url}
    end
  end

  def replay_dataset(
        state = %{dataset: [_ | _]},
        options
      ) do
    [{ts_ms, file_name, session_ts, payload} | rest_dataset] = state.dataset

    if rem(state.processed_packets, 5000) == 0 and !!options[:report_progress] do
      percent = round(state.processed_packets / state.total_packets * 100)

      Logger.info(
        "Replay status: #{state.processed_packets}/#{state.total_packets} (#{percent} %)"
      )
    end

    [topic | _] = String.split(file_name, ".")

    # Re-synchronize time
    base_ts =
      if topic == "Heartbeat" do
        base_ts = calculate_base_time(session_ts, payload["Utc"])

        # Logger.debug("Time synchronization: #{Timex.Duration.to_string(timestamp)} = #{payload["Utc"]}")
        base_ts
      else
        state.base_ts
      end

    timestamp = Timex.add(base_ts, session_ts)

    packet = %Packet{
      topic: topic,
      data: payload,
      timestamp: timestamp
    }

    # Pause the replay if provided `replay_while_fn/1` returns false, this allows
    # us to process events in small chunks to provide a live-like experience.
    # This only makes sense in conjunction with a custom packets_fn as described below.
    if options[:replay_while_fn] != nil and !options[:replay_while_fn].(state, packet, ts_ms) do
      state
    else
      # Determine the handler function for this packet
      #
      # By default we use default_packets_fn/3 which updates the session
      # without any additional side effects.
      #
      # Alternatively we might want to provide a custom function that
      # sends packets to the F1Session.Server instance to get
      # a live replay that behaves like a live race and can be observed on the website.
      packets_fn = Map.get(options, :packets_fn, &default_packets_fn/3)
      state = packets_fn.(state, options, packet)

      state = %{
        state
        | dataset: rest_dataset,
          processed_packets: state.processed_packets + 1,
          base_ts: base_ts
      }

      replay_dataset(state, options)
    end
  end

  def replay_dataset(state = %{dataset: []}, options) do
    if options[:report_progress] do
      Logger.info("Replay completed.")
    end

    state
  end

  defp default_packets_fn(state, options, packet) do
    ingest_options = %{
      log_stray_packets: false
    }

    {session, events} =
      case LiveTimingHandlers.process_live_timing_packet(state.session, packet, ingest_options) do
        {:ok, session, events} ->
          {session, events}

        {:error, err} ->
          Logger.error(inspect(err))
          {state.session, []}
      end

    if length(events) > 0 and options[:events_fn] != nil do
      options[:events_fn].(events)
    end

    %{state | session: session}
  end

  defp download_dataset(base_url, options) do
    files(options[:exclude_files_regex])
    |> Enum.map(fn f -> {f, download_file(base_url, f, options)} end)
    # Ignore failed downloads
    |> Enum.filter(fn {_f, {:ok, _}} -> true; _ -> false end)
    # Parse contents
    |> Enum.map(fn {f, {:ok, contents}} -> parse_file(f, contents) end)
  end

  defp fetch_base_time(base_url, options) do
    {session_ts, json} =
      base_url
      |> download_file("Heartbeat.jsonStream", options)
      |> elem(1)
      |> base_parse_file()
      |> List.last()

    {:ok, session_ts} = F1Bot.DataTransform.Parse.parse_session_time(session_ts)
    data = Jason.decode!(json)

    calculate_base_time(session_ts, data["Utc"])
  end

  defp calculate_base_time(session_ts = %Timex.Duration{}, utc_string)
       when is_binary(utc_string) do
    wall_ts = F1Bot.DataTransform.Parse.parse_iso_timestamp(utc_string)
    Timex.subtract(wall_ts, session_ts)
  end

  defp download_file(base_url, file_name, options) do
    full_url = base_url <> "/" <> file_name

    if !!options[:report_progress] do
      Logger.info("Replay downloading: #{full_url}")
    end

    res =
      Finch.build(:get, full_url)
      |> Finch.request(F1Bot.Finch)

    case res do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      _ ->
        Logger.warn("Replay download failed: #{full_url}")
        :error
    end
  end

  defp parse_file(file_name, contents) do
    contents
    |> base_parse_file()
    |> Enum.map(fn {timestamp, json} ->
      {:ok, session_ts} = F1Bot.DataTransform.Parse.parse_session_time(timestamp)
      ts_ms = session_ts |> Timex.Duration.to_milliseconds() |> round()

      data = Jason.decode!(json)
      {ts_ms, file_name, session_ts, data}
    end)
  end

  defp base_parse_file(contents) do
    contents
    |> String.trim_leading("\uFEFF")
    |> String.split("\r\n")
    |> Enum.reject(fn x -> String.length(x) < 10 end)
    |> Enum.map(fn x -> String.split_at(x, 12) end)
  end

  defp files(exclude_files_regex) do
    {:ok, topics} = F1Bot.fetch_env(:signalr_topics)

    topics
    |> Enum.map(&"#{&1}.jsonStream")
    |> Enum.reject(&(exclude_files_regex != nil and &1 =~ exclude_files_regex))
  end
end
