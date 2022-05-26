defmodule F1Bot.ExternalApi.Discord.Live do
  @moduledoc ""
  use GenServer
  require Logger
  @behaviour F1Bot.ExternalApi.Discord

  @delay_ms 25_000
  @server_via __MODULE__

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: @server_via)
  end

  @impl GenServer
  def init(_) do
    {:ok, nil}
  end

  @impl GenServer
  def handle_info({:post_message, message}, state) do
    {:ok, channel_ids} = F1Bot.fetch_env(:discord_channel_ids_messages)

    for channel_id <- channel_ids do
      Nostrum.Api.create_message(channel_id, message)
    end

    {:noreply, state}
  end

  @impl F1Bot.ExternalApi.Discord
  def post_message(message) do
    case GenServer.whereis(@server_via) do
      nil ->
        Logger.error("DiscordApi.Live server is not running, unable to post message.")

      pid ->
        :timer.send_after(@delay_ms, pid, {:post_message, message})
    end
  end
end
