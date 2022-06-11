defmodule F1Bot.ExternalApi.Discord.Commands.Response do
  @moduledoc """
  Functions for composing and sending responses to slash commands.
  """
  use Bitwise
  require Logger
  alias Nostrum.Api

  @type flags :: :ephemeral

  # https://discord.com/developers/docs/resources/channel#message-object-message-flags
  @flags %{
    ephemeral: 1 <<< 6
  }

  # https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-interaction-callback-type
  @interaction_callback_type %{
    channel_message: 4,
    deferred_channel_message: 5
  }

  def send_interaction_response(response, interaction) do
    Api.create_interaction_response(interaction, response)
  end

  # Silence Dialyzer warnings due to bad Nostrum API types
  @dialyzer {:nowarn_function, send_followup_response: 2}
  def send_followup_response(response, interaction) do
    Api.create_followup_message(interaction.token, response)
    |> maybe_handle_followup_error()
  end

  def make_message(flags, message) when is_list(flags) do
    %{
      type: @interaction_callback_type.channel_message,
      data: %{
        content: message,
        flags: combine_flags(flags)
      }
    }
  end

  def make_deferred_message(flags) when is_list(flags) do
    %{
      type: @interaction_callback_type.deferred_channel_message,
      data: %{
        flags: combine_flags(flags)
      }
    }
  end

  def make_followup_message(flags, content, files \\ [], embeds \\ [])
      when is_list(flags) and is_list(embeds) do
    %{
      content: content,
      embeds: embeds,
      files: files,
      flags: combine_flags(flags)
    }
  end

  def combine_flags(flags) do
    Enum.reduce(flags, 0, fn flag, combined ->
      flag_val = Map.fetch!(@flags, flag)
      combined ||| flag_val
    end)
  end

  defp maybe_handle_followup_error(res = {:ok, _}), do: res

  defp maybe_handle_followup_error(res = {:error, error}) do
    Logger.error("Error occurred while posting command followup message: #{inspect(error)}")
    res
  end
end
