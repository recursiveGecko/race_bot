defmodule F1Bot.ExternalApi.Discord.Commands.Definition do
  @moduledoc """
  Factory functions for composable Discord commands
  """

  alias Nostrum.Struct.ApplicationCommand

  @type application_command_map :: ApplicationCommand.application_command_map()
  @type command_option :: ApplicationCommand.command_option()

  @type command_params :: %{
          name: String.t(),
          description: String.t(),
          default_permission: boolean()
        }

  @option_type %{
    string: 3,
    integer: 4
  }

  @spec cmd_graph(command_params()) :: application_command_map()
  def cmd_graph(options) do
    name = Map.fetch!(options, :name)
    description = Map.fetch!(options, :description)
    default_permission = Map.fetch!(options, :default_permission)

    %{
      name: name,
      description: description,
      default_permission: default_permission,
      options: [
        option_plot_metric("metric", true),
        option_driver_list("drivers", true),
        option_plot_style("style", true)
      ]
    }
  end

  @spec cmd_driver_summary(command_params()) :: application_command_map()
  def cmd_driver_summary(options) do
    name = Map.fetch!(options, :name)
    description = Map.fetch!(options, :description)
    default_permission = Map.fetch!(options, :default_permission)

    %{
      name: name,
      description: description,
      default_permission: default_permission,
      options: [
        option_driver_list("drivers", true)
      ]
    }
  end

  @spec option_plot_metric(String.t(), boolean()) :: command_option()
  def option_plot_metric(name, required) do
    %{
      type: @option_type.string,
      name: name,
      description: "Metric to plot",
      choices: [
        %{
          name: "Gap to first driver",
          value: "gap"
        },
        %{
          name: "Lap times",
          value: "lap_time"
        }
      ],
      required: required
    }
  end

  @spec option_plot_style(String.t(), boolean()) :: command_option()
  def option_plot_style(name, required) do
    %{
      type: @option_type.string,
      name: name,
      description: "Plot style",
      choices: [
        %{
          name: "Points",
          value: "points"
        },
        %{
          name: "Line",
          value: "lines"
        }
      ],
      required: required
    }
  end

  @spec option_driver_list(String.t(), boolean()) :: command_option()
  def option_driver_list(name, required) do
    %{
      type: @option_type.string,
      name: name,
      description: "Comma-separated list of drivers (number or 3 letter abbreviation)",
      required: required
    }
  end

  @spec option_driver(String.t(), boolean()) :: command_option()
  def option_driver(name, required) do
    %{
      type: @option_type.string,
      name: name,
      description: "Driver number or 3 letter abbreviation",
      required: required
    }
  end
end
