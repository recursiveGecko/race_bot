defmodule F1Bot.ExternalApi.Discord.Handlers.GraphCommand do
  @moduledoc """
  Handles Discord command for creating graphs
  """
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Interaction
  alias F1Bot.Plotting
  alias F1Bot

  @resp_with_msg_type 4
  @delayed_resp_with_msg_type 5

  @dialyzer {:nowarn_function, {:handle_interaction, 1}}
  def handle_interaction(
        interaction = %Interaction{
          data: %{
            options: options
          }
        }
      ) do
    if ensure_eligibility(interaction) == :ok do
      Api.create_interaction_response(interaction, loading_response())

      parsed_opts = parse_interaction_args(options)

      case parsed_opts do
        {:error, error} ->
          Api.create_followup_message(interaction.token, %{
            content: "Error: #{error}"
          })

        {:ok, parsed_opts} ->
          do_create_chart(interaction, parsed_opts)
      end
    else
      resp = message_response("This command is not available.")
      Api.create_interaction_response(interaction, resp)
    end
  end

  @dialyzer {:nowarn_function, {:do_create_chart, 2}}
  defp do_create_chart(interaction, options) do
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
        Api.create_followup_message(interaction.token, %{
          file: file_path,
          content: "graph.png",
          tts: false
        })

        Plotting.cleanup(file_path)

      {:error, :dataset_empty} ->
        Api.create_followup_message(interaction.token, %{
          content: "Data is not available yet."
        })

      {:error, error} ->
        Logger.error("Error generating chart: #{inspect(error)}")

        Api.create_followup_message(interaction.token, %{
          content: "Something went wrong."
        })
    end
  end

  defp parse_interaction_args(options) do
    with {:ok, metric} <- get_graph_metric(options),
         {:ok, drivers} <- get_driver_list(options),
         {:ok, style} <- get_graph_style(options) do
      opts = %{
        metric: metric,
        drivers: drivers,
        style: style
      }

      {:ok, opts}
    end
  end

  defp get_graph_metric(options) do
    metric_option = Enum.find(options, fn opt -> opt.name == "metric" end)

    case metric_option do
      %{value: x} when x in ["gap", "lap_time"] -> {:ok, String.to_atom(x)}
      nil -> {:error, "Metric option not provided"}
      _ -> {:error, "Invalid metric option"}
    end
  end

  defp get_graph_style(options) do
    metric_option = Enum.find(options, fn opt -> opt.name == "style" end)

    case metric_option do
      %{value: x} when x in ["points", "lines"] -> {:ok, String.to_atom(x)}
      nil -> {:ok, :line}
      _ -> {:error, "Invalid style option"}
    end
  end

  defp get_driver_list(options) do
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

  def find_driver_number(str) do
    with {:error, _} <- F1Bot.driver_info_by_abbr(str),
         {:error, _} <- F1Bot.driver_info(str) do
      {:error, "Unknown driver #{str}"}
    else
      {:ok, %{driver_number: num}} ->
        {:ok, num}
    end
  end

  defp loading_response, do: %{type: @delayed_resp_with_msg_type}

  defp message_response(msg),
    do: %{
      type: @resp_with_msg_type,
      data: %{
        content: msg
      }
    }

  defp ensure_eligibility(%Interaction{
         channel_id: channel_id
       }) do
    allowed_channels = F1Bot.get_env(:discord_channel_ids_commands, [])

    if channel_id in allowed_channels do
      :ok
    else
      :error
    end
  end
end
