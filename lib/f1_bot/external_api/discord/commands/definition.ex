defmodule F1Bot.ExternalApi.Discord.Commands.Definition do
  @moduledoc """
  Factory functions for composable Discord commands
  """

  @option_type %{
    string: 3,
    integer: 4
  }

  def cmd_graph(options) do
    name = Keyword.get(options, :name)
    description = Keyword.fetch!(options, :description)
    default_permission = Keyword.fetch!(options, :default_permission)

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

  def option_driver_list(name, required) do
    %{
      type: @option_type.string,
      name: name,
      description: "Comma-separated list of drivers (number or 3 letter abbrv.)",
      required: required
    }
  end
end
