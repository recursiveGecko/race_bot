defmodule F1Bot.DataTransform.Format do
  @moduledoc false
  alias F1Bot.DataTransform.Format

  def format_lap_time(duration) do
    case Timex.format_duration(duration, Format.LapTimeDuration) do
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
end
