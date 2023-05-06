defmodule F1Bot.ExternalApi.Discord.Console do
  @moduledoc ""
  @behaviour F1Bot.ExternalApi.Discord
  require Logger

  def post_message(message_or_tuple) do
    message =
      case message_or_tuple do
        {_type, message} -> message
        message -> message
      end

    Logger.info("[DISCORD] #{message}")
  end
end
