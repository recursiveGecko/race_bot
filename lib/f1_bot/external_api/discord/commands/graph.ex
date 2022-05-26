defmodule F1Bot.ExternalApi.Discord.Commands.Graph do
  @moduledoc """
  Handles Discord command for creating graphs
  """
  use Bitwise
  require Logger
  alias Nostrum.Struct.Interaction
  alias F1Bot
  alias F1Bot.ExternalApi.Discord
  alias F1Bot.ExternalApi.Discord.Commands.Response
  alias F1Bot.Plotting

  @behaviour Discord.Commands

  @impl Discord.Commands
  def handle_interaction(interaction = %Interaction{}, internal_args) do
    flags = Map.get(internal_args, :flags, [])

    case parse_interaction_options(interaction) do
      {:ok, parsed_opts} ->
        flags
        |> Response.make_deferred_message()
        |> Response.send_interaction_response(interaction)

        do_create_chart(interaction, parsed_opts, internal_args)

      {:error, option_error} ->
        flags
        |> Response.make_message("Error: #{option_error}")
        |> Response.send_interaction_response(interaction)
    end
  end

  # Silence Dialyzer warnings for bad &Api.create_followup_message/2 types
  @dialyzer {:no_fail_call, do_create_chart: 3}
  @dialyzer {:no_return, do_create_chart: 3}
  defp do_create_chart(interaction, options, internal_args) do
    flags = Map.get(internal_args, :flags, [])

    {:ok, info} = F1Bot.session_info()

    chart_response =
      case options.metric do
        :gap ->
          Plotting.plot_gap(options.drivers, style: options.style)

        :lap_time ->
          x_axis = if info.type =~ ~r/^(quali|practice)/iu, do: :timestamp, else: :lap
          Plotting.plot_lap_times(options.drivers, style: options.style, x_axis: x_axis)
      end

    case chart_response do
      {:ok, file_path} ->
        flags
        |> Response.make_followup_message(nil, [file_path])
        |> Response.send_followup_response(interaction)

        Plotting.cleanup(file_path)

      {:error, :dataset_empty} ->
        flags
        |> Response.make_followup_message("Data is not available yet.")
        |> Response.send_followup_response(interaction)

      {:error, error} ->
        Logger.error("Error generating chart: #{inspect(error)}")

        flags
        |> Response.make_followup_message("Something went wrong.")
        |> Response.send_followup_response(interaction)
    end
  end

  defp parse_interaction_options(interaction = %Interaction{}) do
    %Interaction{
      data: %{
        options: options
      }
    } = interaction

    with {:ok, metric} <- validate_graph_metric(options),
         {:ok, drivers} <- validate_driver_list(options),
         {:ok, style} <- validate_graph_style(options) do
      opts = %{
        metric: metric,
        drivers: drivers,
        style: style
      }

      {:ok, opts}
    end
  end

  defp validate_graph_metric(options) do
    metric_option = Enum.find(options, fn opt -> opt.name == "metric" end)

    case metric_option do
      %{value: x} when x in ["gap", "lap_time"] -> {:ok, String.to_atom(x)}
      nil -> {:error, "Metric option not provided"}
      _ -> {:error, "Invalid metric option"}
    end
  end

  defp validate_graph_style(options) do
    metric_option = Enum.find(options, fn opt -> opt.name == "style" end)

    case metric_option do
      %{value: x} when x in ["points", "lines"] -> {:ok, String.to_atom(x)}
      nil -> {:ok, :line}
      _ -> {:error, "Invalid style option"}
    end
  end

  defp validate_driver_list(options) do
    drivers_option = Enum.find(options, fn opt -> opt.name == "drivers" end)

    if drivers_option != nil do
      drivers =
        drivers_option.value
        |> String.split([",", " "])
        |> Enum.map(&String.replace(&1, ~r/[., ]/, ""))
        |> Enum.filter(fn x -> String.length(x) > 0 end)

      drivers =
        for str <- drivers do
          find_driver_number(str)
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

  defp find_driver_number(str) do
    driver_number =
      case Integer.parse(str) do
        :error -> -1
        {int, _} -> int
      end

    with {:error, _} <- F1Bot.driver_info_by_abbr(str),
         {:error, _} <- F1Bot.driver_info(driver_number) do
      {:error, "Unknown driver #{str}"}
    else
      {:ok, %{driver_number: num}} ->
        {:ok, num}
    end
  end
end
