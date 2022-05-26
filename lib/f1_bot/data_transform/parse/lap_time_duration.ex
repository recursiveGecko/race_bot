defmodule F1Bot.DataTransform.Parse.LapTimeDuration do
  @moduledoc false
  use Timex.Parse.Duration.Parser
  import NimbleParsec

  @impl true
  def parse(lap_time_str) do
    case parse_lap_time(lap_time_str) do
      {:ok, [min, sec, mil], _remaining, _, _, _} ->
        microseconds = mil * 1000 + sec * 1_000_000 + min * 60 * 1_000_000

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
  ## Lap time parser, e.g. 1:15.234 into [1, 15, 234]
  ## Minutes are optional and replaced by 0, e.g. "59.212" -> [0, 59, 212]
  ##

  lap_time_minutes_parser =
    choice([
      integer(min: 1)
      |> ignore(ascii_char([?:])),
      empty()
      |> replace(0)
    ])

  lap_time_seconds_parser =
    integer(min: 1, max: 2)
    |> ignore(ascii_char([?.]))

  lap_time_milliseconds_parser = integer(min: 1, max: 3)

  lap_time_combined =
    lap_time_minutes_parser
    |> concat(lap_time_seconds_parser)
    |> concat(lap_time_milliseconds_parser)

  defparsecp(:parse_lap_time, lap_time_combined)
end
