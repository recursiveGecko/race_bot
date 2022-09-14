defmodule F1Bot.DataTransform.Parse.SessionClock do
  @moduledoc false
  use Timex.Parse.Duration.Parser
  import NimbleParsec

  @impl true
  def parse(timestamp_string) do
    case parse_timestamp(timestamp_string) do
      {:ok, [hour, min, sec], _remaining, _, _, _} ->
        total_ms = sec * 1_000 + min * 60 * 1_000 + hour * 3600 * 1_000
        duration = Timex.Duration.from_milliseconds(total_ms)

        {:ok, duration}

      {:error, error, _, _, _, _} ->
        {:error, error}
    end
  end

  ##
  ## Session clock parser, e.g. 0:17:45 into [0, 17, 45]
  ##

  non_second_parser =
    integer(min: 1)
    |> ignore(ascii_char([?:]))

  second_parser =
    integer(min: 1)

  timestamp_combined =
    non_second_parser
    |> concat(non_second_parser)
    |> concat(second_parser)

  defparsecp(:parse_timestamp, timestamp_combined)
end
