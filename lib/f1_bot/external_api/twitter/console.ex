defmodule F1Bot.ExternalApi.Twitter.Console do
  @moduledoc ""
  @behaviour F1Bot.ExternalApi.Twitter
  require Logger

  @impl F1Bot.ExternalApi.Twitter
  def post_tweet(message) do
    Logger.info("[TWITTER] #{message}")
  end
end
