defmodule F1Bot.ExternalApi.Discord.Commands.Graph do
  @moduledoc """
  Handles Discord command for creating graphs
  """
  use Bitwise
  require Logger
  alias Nostrum.Struct.Interaction
  alias F1Bot
  alias F1Bot.ExternalApi.Discord
  alias F1Bot.ExternalApi.Discord.Commands.{Response, OptionValidator}
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

    with {:ok, metric} <- OptionValidator.validate_graph_metric(options, "metric"),
         {:ok, drivers} <- OptionValidator.validate_driver_list(options, "drivers"),
         {:ok, style} <- OptionValidator.validate_graph_style(options, "style") do
      opts = %{
        metric: metric,
        drivers: drivers,
        style: style
      }

      {:ok, opts}
    end
  end
end
