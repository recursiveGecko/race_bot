defmodule F1Bot.DataTransform.Parse do
  @moduledoc false
  alias F1Bot.DataTransform.Parse

  defdelegate parse_lap_time(str), to: Parse.LapTimeDuration, as: :parse
  defdelegate parse_session_time(str), to: Parse.SessionTime, as: :parse
  defdelegate parse_session_clock(str), to: Parse.SessionClock, as: :parse

  def parse_iso_timestamp(str) do
    {:ok, datetime} = Timex.parse(str, "{ISO:Extended}")

    datetime
  end
end
