defmodule F1Bot.ExternalApi.Discord.Live do
  @moduledoc ""
  require Logger
  @behaviour F1Bot.ExternalApi.Discord

  @impl F1Bot.ExternalApi.Discord
  def post_message(message_or_tuple) do
    {type, message} =
      case message_or_tuple do
        message when is_binary(message) -> {:default, message}
        {type, message} -> {type, message}
      end

    channel_ids =
      case type do
        :radio -> F1Bot.get_env(:discord_channel_ids_radios, [])
        _ -> F1Bot.get_env(:discord_channel_ids_messages, [])
      end

    Logger.info("[DISCORD] #{message} (to channels: #{inspect(channel_ids)})")

    for channel_id <- channel_ids do
      case Nostrum.Api.create_message(channel_id, message) do
        {:ok, _result} ->
          :ok

        {:error, err} ->
          Logger.error("Failed to post Discord message: #{inspect(err)}")
      end
    end

    :ok
  end
end
