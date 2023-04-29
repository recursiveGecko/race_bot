defmodule F1Bot.ExternalApi.Twitter.Live do
  @moduledoc ""
  require Logger
  @behaviour F1Bot.ExternalApi.Twitter

  @impl F1Bot.ExternalApi.Twitter
  def post_tweet(message) do
    try do
      ExTwitter.update(message, tweet_mode: "extended")
      :ok
    rescue
      e in ExTwitter.ConnectionError ->
        Logger.error("Twitter POST tweet error: #{e.reason}")
        {:error, e}

      e in ExTwitter.Error ->
        Logger.error("Twitter POST tweet error: #{e.message}")
        {:error, e}
    end
  end
end
