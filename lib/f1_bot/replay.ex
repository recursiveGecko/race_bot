defmodule F1Bot.Replay do
  require Logger

  alias F1Bot.F1Session.LiveTimingHandlers.Packet
  alias F1Bot.F1Session.LiveTimingHandlers
  alias F1Bot.F1Session

  def session_from_url(url, options \\ %{}) do
    if String.starts_with?(url, "http://livetiming.formula1.com/static/") do
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

      session =
        F1Session.new()
        |> replay_dataset(options, dataset, {0, total}, base_ts)

      {:ok, session}
    else
      {:error, :invalid_url}
    end
  end

  defp replay_dataset(
         session,
         options,
         [{_ts_ms, file_name, session_ts, payload} | rest],
         {count, total},
         base_ts
       ) do
    if rem(count, 5000) == 0 and !!options[:report_progress] do
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

    packet = %Packet{
      topic: topic,
      data: payload,
      timestamp: timestamp
    }

    ingest_options = %{
      log_stray_packets: false
    }

    {session, events} =
      case LiveTimingHandlers.process_live_timing_packet(session, packet, ingest_options) do
        {:ok, session, events} ->
          {session, events}

        {:error, err} ->
          Logger.error(err)
          {session, []}
      end

    if length(events) > 0 and options[:events_fn] != nil do
      options[:events_fn].(events)
    end

    replay_dataset(session, options, rest, {count + 1, total}, base_ts)
  end

  defp replay_dataset(session, options, [], {_count, _total}, _ts_offset) do
    if !!options[:report_progress] do
      Logger.info("Replay completed.")
    end

    session
  end

  defp download_dataset(base_url, options) do
    files(options[:exclude_files_regex])
    |> Enum.map(fn f -> {f, download_file(base_url, f, options)} end)
    |> Enum.map(fn {f, c} -> parse_file(f, c) end)
  end

  defp fetch_base_time(base_url, options) do
    {session_ts, json} =
      base_url
      |> download_file("Heartbeat.jsonStream", options)
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

    {:ok, %{status: 200, body: body}} =
      Finch.build(:get, full_url)
      |> Finch.request(F1Bot.Finch)

    body
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
