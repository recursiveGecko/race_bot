defmodule F1Bot.ExternalApi.Twitter.Live do
  @moduledoc ""
  use GenServer
  require Logger
  @behaviour F1Bot.ExternalApi.Twitter

  @server_via __MODULE__
  @delay_ms 25_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: @server_via)
  end

  @impl GenServer
  def init(_) do
    {:ok, configuration} = F1Bot.fetch_env(:extwitter_config)
    ExTwitter.configure(:process, configuration)

    {:ok, nil}
  end

  @impl GenServer
  def handle_info({:post_tweet, message}, state) do
    try do
      ExTwitter.update(message, tweet_mode: "extended")
    rescue
      e in ExTwitter.ConnectionError ->
        Logger.error("Twitter POST tweet error: #{e.reason}")

      e in ExTwitter.Error ->
        Logger.error("Twitter POST tweet error: #{e.message}")
    end

    {:noreply, state}
  end

  @impl F1Bot.ExternalApi.Twitter
  def post_tweet(message) do
    case GenServer.whereis(@server_via) do
      nil ->
        Logger.error("TwitterApi.Live server is not running, unable to post tweet.")

      pid ->
        :timer.send_after(@delay_ms, pid, {:post_tweet, message})
    end
  end
end
