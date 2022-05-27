defmodule F1Bot.LiveTimingHandlers.RaceControlMessages do
  @moduledoc """
  Handler for race control messages received from live timing API.

  The handler parses, filters and passes the messages to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.F1Session.RaceControl
  alias F1Bot.LiveTimingHandlers.Event
  @scope "RaceControlMessages"

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: data
      }) do
    messages =
      data
      |> extract_messages()
      |> parse_message()
      |> filter_messages()

    if length(messages) > 0 do
      F1Bot.F1Session.push_race_control_messages(messages)
    end

    :ok
  end

  defp extract_messages(_data = %{"Messages" => msgs = [_ | _]}), do: msgs
  defp extract_messages(_data = %{"Messages" => msgs = %{}}), do: Map.values(msgs)

  defp parse_message(messages) do
    for m <- messages do
      flag =
        case m["Flag"] do
          s when is_binary(s) -> s |> String.downcase() |> String.trim() |> String.to_atom()
          _ -> nil
        end

      {source, message} =
        case m["Message"] do
          s when is_binary(s) ->
            {source, message} = s |> String.trim() |> detect_source_and_change_message()
            message = recapitalize(message)
            {source, message}

          _ ->
            {nil, nil}
        end

      mentions = find_driver_mentions(message)

      %RaceControl.Message{
        flag: flag,
        message: message,
        mentions: mentions,
        source: source
      }
    end
  end

  defp filter_messages(msgs) do
    msgs
    |> Stream.reject(fn m -> m.flag in [:blue, :clear] end)
    # |> Enum.reject(fn m -> m.message =~ ~r/TIME.*DELETED/iu end)
    |> Stream.reject(fn m -> m.message =~ ~r/OFF TRACK AND CONTINUED/iu end)
    |> Stream.reject(fn m -> m.message =~ ~r/MISSED THE APEX/iu end)
    |> Stream.reject(fn m -> m.message =~ ~r/^ (FOR|OF) (F3|F2)\s.*SESSION/iu end)
    |> Enum.to_list()
  end

  defp detect_source_and_change_message(message) do
    sources = [
      {:stewards, ~r/^FIA stewards/iu, ~r/^FIA stewards:\s*/iu, ""},
      {:stewards_correction, ~r/^Correction FIA stewards/iu, ~r/^Correction FIA stewards:\s*/iu,
       ""}
    ]

    default = {:race_control, message}

    sources
    |> Enum.find_value(default, fn {source, regex, replace_regex, replace_with} ->
      if message =~ regex do
        message = String.replace(message, replace_regex, replace_with)
        {source, message}
      else
        nil
      end
    end)
  end

  defp recapitalize(msg) do
    # Word separator start &  end
    wss = "(^|[^\w])"
    wse = "($|[^\w])"

    patterns = [
      # General abbrevations
      ~r/#{wss}(FIA|F1|DRS|VSC|SC)#{wse}/iu,
      # 3 letter drive abbrevations
      ~r/\(\w{3}\)/iu
    ]

    msg
    |> String.downcase()
    |> String.split(". ")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.capitalize/1)
    |> Enum.map_join(". ", &do_recapitalize_regex(&1, patterns))
  end

  defp do_recapitalize_regex(string, []), do: string

  defp do_recapitalize_regex(string, [regex | rest]) do
    string
    |> String.replace(regex, fn s -> String.upcase(s) end)
    |> do_recapitalize_regex(rest)
  end

  defp find_driver_mentions(message) do
    ~r/\((\w{3})\)/
    |> Regex.scan(message)
    |> Enum.map(fn [_whole, abbr] -> abbr end)
  end
end
