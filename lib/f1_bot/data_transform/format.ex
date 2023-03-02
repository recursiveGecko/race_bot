defmodule F1Bot.DataTransform.Format do
  @moduledoc false
  alias F1Bot.DataTransform.Format

  def format_lap_time(duration, maybe_drop_minutes \\ false) do
    formatter =
      if maybe_drop_minutes and Timex.Duration.to_milliseconds(duration) < 60_000 do
        Format.LapTimeDurationNoMinutes
      else
        Format.LapTimeDuration
      end

    case Timex.format_duration(duration, formatter) do
      {:error, _err} -> "ERROR"
      val -> val
    end
  end

  def format_lap_delta(_duration = nil), do: "+-0.000"

  def format_lap_delta(duration) do
    case Timex.format_duration(duration, Format.LapTimeDelta) do
      {:error, _err} -> "ERROR"
      val -> val
    end
  end

  def format_session_clock(duration) do
    case Timex.format_duration(duration, Format.SessionClock) do
      {:error, _err} -> "--:--:--"
      val -> val
    end
  end
end
