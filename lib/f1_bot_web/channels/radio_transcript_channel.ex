defmodule F1BotWeb.RadioTranscriptChannel do
  use F1BotWeb, :channel
  require Logger

  alias F1Bot.TranscriberService
  alias F1BotWeb.ApiSocket

  @impl true
  def join("radio_transcript:status", _payload, socket) do
    if ApiSocket.client_has_scope?(socket, :read_transcripts) do
      send(self(), {:after_join, :status})
      {:ok, socket}
    else
      {:error, :unauthorized}
    end
  end

  @impl true
  def join("radio_transcript:" <> _driver_number, _payload, socket) do
    if ApiSocket.client_has_scope?(socket, :read_transcripts) do
      {:ok, socket}
    else
      {:error, :unauthorized}
    end
  end

  @impl true
  def handle_info({:after_join, :status}, socket) do
    status = TranscriberService.status()
    push(socket, "status", status)
    {:noreply, socket}
  end
end
