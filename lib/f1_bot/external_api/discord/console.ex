defmodule F1Bot.ExternalApi.Discord.Console do
  @moduledoc ""
  @behaviour F1Bot.ExternalApi.Discord
  require Logger

  def post_message(message) do
    Logger.info("[DISCORD] #{message}")
  end
end
