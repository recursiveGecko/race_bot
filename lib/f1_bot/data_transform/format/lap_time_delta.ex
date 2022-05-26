defmodule F1Bot.DataTransform.Format.LapTimeDelta do
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
      |> abs()

    seconds =
      total_mils
      |> div(1000)
      |> rem(60)
      |> abs()

    minutes =
      total_mils
      |> div(1000)
      |> div(60)
      |> abs()

    vals = {minutes, seconds, milliseconds}

    sign =
      if total_mils < 0 do
        "-"
      else
        "+"
      end

    sign
    |> maybe_add_minutes(vals)
    |> maybe_add_seconds(vals)
    |> maybe_add_milliseconds(vals)
  end

  @impl true
  def lformat(duration, _), do: format(duration)

  defp maybe_add_minutes(str, {min, _sec, _ms}) when min > 0, do: str <> "#{min}:"
  defp maybe_add_minutes(str, {_min, _sec, _ms}), do: str

  defp maybe_add_seconds(str, {min, sec, _ms}) when min == 0, do: str <> "#{sec}."

  defp maybe_add_seconds(str, {_min, sec, _ms}),
    do: str <> String.pad_leading("#{sec}", 2, "0") <> "."

  defp maybe_add_milliseconds(str, {_min, _sec, ms}),
    do: str <> String.pad_leading("#{ms}", 3, "0")
end
