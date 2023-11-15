defmodule F1Bot.ExternalApi.Discord.Commands do
  @moduledoc """
  Handles Discord command management and event processing.
  """
  use Nostrum.Consumer
  require Logger
  alias Nostrum.Api
  alias Nostrum.Struct.Interaction
  alias F1Bot.ExternalApi.Discord.Commands
  alias F1Bot.ExternalApi.Discord.Commands.Definition

  @type internal_args :: %{
          required(:flags) => [Commands.Response.flags()]
        }

  @callback handle_interaction(Interaction.t(), internal_args()) :: any()

  def create_commands() do
    command_mode = F1Bot.get_env(:discord_command_mode, :guild)
    server_ids = F1Bot.get_env(:discord_server_ids_commands, [])

    if command_mode == :global do
      Logger.info("Creating global slash commands")

      Api.bulk_overwrite_global_application_commands(commands())

      for guild_id <- server_ids do
        Logger.info("Removing guild-specific slash commands for guild #{guild_id}")
        Api.bulk_overwrite_guild_application_commands(guild_id, [])
      end
    else
      for guild_id <- server_ids do
        Logger.info("Creating commands for guild #{guild_id}")
        Api.bulk_overwrite_guild_application_commands(guild_id, commands())
      end

      Logger.info("Deleting global slash commands")
      Api.bulk_overwrite_global_application_commands([])
    end
  end

  def commands do
    [
      Definition.cmd_graph(%{
        name: "f1graph",
        description: "Create a graph for the current F1 session (responds privately)",
        default_permission: true
      }),
      Definition.cmd_graph(%{
        name: "f1graphall",
        description: "Create a graph for the current F1 session (responds publicly)",
        default_permission: false
      }),
      Definition.cmd_driver_summary(%{
        name: "f1summary",
        description:
          "Display driver's fastest lap, top speed and detailed stint information (responds privately)",
        default_permission: true
      }),
      Definition.cmd_driver_summary(%{
        name: "f1summaryall",
        description:
          "Display driver's fastest lap, top speed and detailed stint information (responds publicly)",
        default_permission: false
      })
    ]
  end

  def handle_event({:READY, _, _}) do
    Logger.info("Discord API Gateway READY")
    create_commands()
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    Logger.info("Handling Discord interaction: #{inspect(interaction)}")

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

  defp handle_interaction(interaction = %Interaction{data: %{name: "f1summary"}}) do
    args = %{
      flags: [:ephemeral]
    }

    Commands.Summary.handle_interaction(interaction, args)
  end

  defp handle_interaction(interaction = %Interaction{data: %{name: "f1summaryall"}}) do
    args = %{
      flags: []
    }

    Commands.Summary.handle_interaction(interaction, args)
  end

  defp handle_interaction(unknown_interaction = %Interaction{data: %{name: name}}) do
    Logger.error("Received unknown interaction #{inspect(name)}: #{inspect(unknown_interaction)}")
  end
end
