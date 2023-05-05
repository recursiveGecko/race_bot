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

    for channel_id <- channel_ids do
      Nostrum.Api.create_message(channel_id, message)
    end

    :ok
  end
end
