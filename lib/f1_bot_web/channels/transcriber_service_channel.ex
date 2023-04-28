defmodule F1BotWeb.TranscriberServiceChannel do
  use F1BotWeb, :channel
  require Logger

  alias Ecto.Changeset
  alias F1Bot.F1Session.Server
  alias F1Bot.F1Session.DriverDataRepo.Transcript

  @impl true
  def join("transcriber_service", _payload, socket) do
    if socket_has_scope?(socket, :transcriber_service) do
      {:ok, socket}
    else
      {:error, :unauthorized}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("transcript", payload, socket) do
    with true <- socket_has_scope?(socket, :transcriber_service),
         {:ok, transcript} <- Transcript.validate(payload),
         :ok <- Server.process_transcript(transcript) do
      Logger.info("Received transcript: #{inspect(transcript)}")
      {:reply, :ok, socket}
    else
      {:error, changeset = %Changeset{}} ->
        Logger.warn("Received invalid transcript: #{inspect(changeset)}")
        {:reply, {:error, :invalid_data}, socket}

      {:error, error} ->
        Logger.error("Failed to process transcript: #{inspect(error)}")
        {:reply, {:error, :internal_error}, socket}

      false ->
        Logger.warn("Unauthorized attempt to submit transcript")
        {:reply, {:error, :unauthorized}, socket}
    end
  end

  def socket_has_scope?(socket, scope) do
    case socket.assigns.authenticated_api_client do
      %F1Bot.Authentication.ApiClient{scopes: scopes} ->
        scope in scopes

      _ ->
        false
    end
  end
end
