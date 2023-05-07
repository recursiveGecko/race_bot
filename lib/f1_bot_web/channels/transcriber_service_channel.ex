defmodule F1BotWeb.TranscriberServiceChannel do
  use F1BotWeb, :channel
  require Logger

  alias Ecto.Changeset
  alias F1Bot.TranscriberService
  alias F1Bot.F1Session.Server
  alias F1Bot.F1Session.DriverDataRepo.Transcript
  alias F1BotWeb.ApiSocket

  @impl true
  def join("transcriber_service", _payload, socket) do
    if ApiSocket.client_has_scope?(socket, :transcriber_service) do
      {:ok, socket}
    else
      {:error, :unauthorized}
    end
  end

  @impl true
  def handle_in("transcript", payload, socket) do
    case Transcript.validate(payload) do
      {:ok, transcript} ->
        process_transcript(transcript, socket)
        {:reply, :ok, socket}

      {:error, changeset = %Changeset{}} ->
        Logger.warn("Received invalid transcript: #{inspect(changeset)}")
        {:reply, {:error, :invalid_data}, socket}
    end
  end

  @impl true
  def handle_in("update-status", payload, socket) do
    case TranscriberService.Status.validate(payload) do
      {:ok, status_update} ->
        TranscriberService.update_status(status_update)
        {:reply, :ok, socket}

      {:error, changeset = %Changeset{}} ->
        Logger.warn("Received invalid status update: #{inspect(changeset)}")
        {:reply, {:error, :invalid_data}, socket}
    end
  end

  defp process_transcript(transcript = %Transcript{}, _socket) do
    Logger.info("Received transcript: #{inspect(transcript)}")
    Server.process_transcript(transcript)
    Transcript.broadcast_to_channels(transcript)
  end
end
