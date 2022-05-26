defmodule F1Bot.ExternalApi.Discord.Commands.OptionValidator do
  @moduledoc """
  Parses and validates Discord command options
  """
  use Bitwise
  alias F1Bot

  def validate_graph_metric(options, name) do
    metric_option = Enum.find(options, fn opt -> opt.name == name end)

    case metric_option do
      %{value: x} when x in ["gap", "lap_time"] -> {:ok, String.to_atom(x)}
      nil -> {:error, "Metric option not provided"}
      _ -> {:error, "Invalid metric option"}
    end
  end

  def validate_graph_style(options, name) do
    metric_option = Enum.find(options, fn opt -> opt.name == name end)

    case metric_option do
      %{value: x} when x in ["points", "lines"] -> {:ok, String.to_atom(x)}
      nil -> {:ok, :line}
      _ -> {:error, "Invalid style option"}
    end
  end

  def validate_driver_list(options, name) do
    drivers_option = Enum.find(options, fn opt -> opt.name == name end)

    if drivers_option != nil do
      drivers =
        drivers_option.value
        |> String.split([",", " "])
        |> Enum.map(&String.replace(&1, ~r/[., ]/, ""))
        |> Enum.filter(fn x -> String.length(x) > 0 end)

      drivers =
        for str <- drivers do
          validate_driver_value(str)
        end

      errors =
        for {status, err} <- drivers,
            status == :error do
          err
        end

      drivers =
        for {status, driver} <- drivers,
            status == :ok do
          driver
        end

      if length(errors) > 0 do
        {:error, errors |> Enum.join(", ")}
      else
        {:ok, drivers}
      end
    else
      {:error, "Drivers option not provided"}
    end
  end

  def validate_driver(options, name) do
    driver_option = Enum.find(options, fn opt -> opt.name == name end)

    if driver_option != nil do
      driver_option.value
      |> String.trim()
      |> validate_driver_value()
    else
      {:error, "Driver option not provided"}
    end
  end

  defp validate_driver_value(str) do
    lookup_result =
      case Integer.parse(str) do
        :error ->
          F1Bot.driver_info_by_abbr(str)

        {int, _} ->
          F1Bot.driver_info(int)
      end

    case lookup_result do
      {:error, _} ->
        {:error, "Unknown driver #{str}"}

      {:ok, %{driver_number: num}} ->
        {:ok, num}
    end
  end
end
