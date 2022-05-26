defmodule F1Bot.ExternalApi.Discord.Commands do
  @moduledoc """
  Handles Discord command management and event processing.
  """
  use Nostrum.Consumer
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Interaction
  alias F1Bot.ExternalApi.Discord.Commands

  @type internal_args :: %{
          required(:flags) => [Commands.Response.flags()]
        }

  @callback handle_interaction(Interaction.t(), internal_args()) :: any()

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
    args = %{
      flags: [:ephemeral]
    }

    Commands.Graph.handle_interaction(interaction, args)
  end

  defp handle_interaction(interaction = %Interaction{data: %{name: "f1graphall"}}) do
    args = %{
      flags: []
    }

    Commands.Graph.handle_interaction(interaction, args)
  end

  defp handle_interaction(unknown_interaction = %Interaction{data: %{name: name}}) do
    Logger.error("Received unknown interaction #{inspect(name)}: #{inspect(unknown_interaction)}")
  end

  defp create_commands() do
    server_ids = F1Bot.get_env(:discord_server_ids_commands, [])

    for guild_id <- server_ids do
      Api.bulk_overwrite_guild_application_commands(guild_id, commands())
    end
  end

  defp commands do
    [
      graph_command(
        name: "f1graph",
        description: "Create a graph for the current F1 session (responds privately)",
        default_permission: false
      ),
      graph_command(
        name: "f1graphall",
        description: "Create a graph for the current F1 session (responds publicly)",
        default_permission: false
      )
    ]
  end

  defp graph_command(options) do
    name = Keyword.get(options, :name)
    description = Keyword.fetch!(options, :description)
    default_permission = Keyword.fetch!(options, :default_permission)

    %{
      name: name,
      description: description,
      default_permission: default_permission,
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
  end
end
