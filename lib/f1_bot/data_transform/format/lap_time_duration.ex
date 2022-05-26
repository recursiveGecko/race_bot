defmodule F1Bot.DataTransform.Format.LapTimeDuration do
  @moduledoc false
  use Timex.Format.Duration.Formatter

  @impl true
  def format(duration) do
    total_mils =
      duration
      |> Timex.Duration.to_milliseconds()
      |> round()

    milliseconds =
      total_mils
      |> rem(1000)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    seconds =
      total_mils
      |> div(1000)
      |> rem(60)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    minutes =
      total_mils
      |> div(1000)
      |> div(60)
      |> Integer.to_string()

    "#{minutes}:#{seconds}.#{milliseconds}"
  end

  @impl true
  def lformat(duration, _), do: format(duration)
end
