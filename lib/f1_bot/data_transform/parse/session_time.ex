defmodule F1Bot.DataTransform.Parse.SessionTime do
  @moduledoc false
  use Timex.Parse.Duration.Parser
  import NimbleParsec

  @impl true
  def parse(timestamp_string) do
    case parse_timestamp(timestamp_string) do
      {:ok, [hour, min, sec, mil], _remaining, _, _, _} ->
        microseconds =
          mil * 1000 + sec * 1_000_000 + min * 60 * 1_000_000 + hour * 3600 * 1_000_000

        duration =
          %Timex.Duration{
            megaseconds: 0,
            seconds: 0,
            microseconds: microseconds
          }
          |> Timex.Duration.normalize()

        {:ok, duration}

      {:error, error, _, _, _, _} ->
        {:error, error}
    end
  end

  ##
  ## Timestamp (session time) parser, e.g. 1:10:15.234 into [1, 10, 15, 234]
  ##

  non_second_parser =
    integer(min: 1)
    |> ignore(ascii_char([?:]))

  second_parser =
    integer(min: 1)
    |> ignore(ascii_char([?.]))

  milliseconds_parser = integer(min: 1, max: 3)

  timestamp_combined =
    non_second_parser
    |> concat(non_second_parser)
    |> concat(second_parser)
    |> concat(milliseconds_parser)

  defparsecp(:parse_timestamp, timestamp_combined)
end
