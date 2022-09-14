defmodule F1Bot.DataTransform.Format.SessionClock do
  @moduledoc false
  use Timex.Format.Duration.Formatter

  @impl true
  def format(duration) do
    total_mils =
      duration
      |> Timex.Duration.to_milliseconds()
      |> round()

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
      |> rem(60)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")


    hours =
      total_mils
      |> div(1000)
      |> div(60)
      |> div(60)
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    "#{hours}:#{minutes}:#{seconds}"
  end

  @impl true
  def lformat(duration, _), do: format(duration)
end
