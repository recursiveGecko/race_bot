defmodule F1Bot.ExternalApi.Discord.Live do
  @moduledoc ""
  require Logger
  @behaviour F1Bot.ExternalApi.Discord

  @impl F1Bot.ExternalApi.Discord
  def post_message(message) do
    {:ok, channel_ids} = F1Bot.fetch_env(:discord_channel_ids_messages)

    for channel_id <- channel_ids do
      Nostrum.Api.create_message(channel_id, message)
    end

    :ok
  end
end
