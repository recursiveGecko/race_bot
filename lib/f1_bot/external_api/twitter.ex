defmodule F1Bot.ExternalApi.Twitter do
  @moduledoc ""
  @callback post_tweet(String.t()) :: :ok | {:error, any()}

  def post_tweet(message) do
    impl = F1Bot.get_env(:twitter_api_module, F1Bot.ExternalApi.Twitter.Console)
    impl.post_tweet(message)
  end
end
