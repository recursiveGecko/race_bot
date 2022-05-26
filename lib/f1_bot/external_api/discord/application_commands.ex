defmodule F1Bot.ExternalApi.Discord.ApplicationCommands do
  @moduledoc """
  Handles Discord command management and event processing.
  """
  use Nostrum.Consumer
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Interaction
  alias F1Bot.ExternalApi.Discord.Handlers.GraphCommand

  @option_type %{
    string: 3,
    integer: 4
  }

  def start_link do
    Consumer.start_link(__MODULE__)
  end

  def handle_event({:READY, _, _}) do
    Logger.info("Discord API Gateway READY")

    create_commands()
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    handle_interaction(interaction)
  end

  def handle_event(_ignored), do: nil

  defp handle_interaction(interaction = %Interaction{data: %{name: "f1graph"}}) do
    GraphCommand.handle_interaction(interaction)
  end

  defp handle_interaction(unknown_interaction = %Interaction{data: %{name: name}}) do
    Logger.error("Received unknown interaction #{inspect(name)}: #{inspect(unknown_interaction)}")
  end

  defp get_all_server_ids(), do: F1Bot.get_env(:discord_server_ids_commands, [])

  defp create_commands() do
    for guild_id <- get_all_server_ids() do
      Api.bulk_overwrite_guild_application_commands(guild_id, commands())
    end
  end

  defp commands do
    [
      %{
        name: "f1graph",
        description: "Create a graph for the current F1 session",
        default_permission: true,
        options: [
          %{
            type: @option_type.string,
            name: "metric",
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
            required: true
          },
          %{
            type: @option_type.string,
            name: "drivers",
            description: "Comma-separated list of drivers (number or 3 letter abbrv.)",
            required: true
          },
          %{
            type: @option_type.string,
            name: "style",
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
            required: true
          }
        ]
      }
    ]
  end
end
