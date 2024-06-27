defmodule F1BotWeb.ApiSocket do
  use Phoenix.Socket
  require Logger

  alias F1Bot.Authentication
  alias F1Bot.Authentication.ApiClient

  channel("transcriber_service", F1BotWeb.TranscriberServiceChannel)
  channel("radio_transcript:*", F1BotWeb.RadioTranscriptChannel)

  @impl true
  def connect(params, socket, _connect_info) do
    with {:ok, client} <- authorized?(socket, params) do
      socket = assign(socket, :authenticated_api_client, client)
      {:ok, socket}
    end
  end

  @impl true
  def id(socket) do
    %ApiClient{client_name: client_name} = socket.assigns.authenticated_api_client
    "api_socket:#{client_name}"
  end

  def authorized?(_socket, params) do
    with %{"token" => token} <- params,
         [client_name, client_secret] <- String.split(token, ":", parts: 2),
         {:ok, client} <- Authentication.find_api_client_by_name(client_name),
         true <- ApiClient.verify_secret(client, client_secret) do
      {:ok, client}
    else
      %{} ->
        Logger.warning("ApiSocket: Missing token")
        {:error, :missing_token}

      parts = [_ | _] ->
        Logger.warning("ApiSocket: Invalid token format (#{length(parts)} parts)")
        {:error, :invalid_token_format}

      {:error, :not_found} ->
        Logger.warning("ApiSocket: Invalid client name")
        {:error, :unauthorized}

      false ->
        Logger.warning("ApiSocket: Invalid client secret")
        {:error, :unauthorized}

      e ->
        Logger.warning("ApiSocket: Unknown error #{inspect(e)}")
        {:error, :unauthorized}
    end
  end

  def client_has_scope?(socket, scope) do
    case socket.assigns[:authenticated_api_client] do
      %F1Bot.Authentication.ApiClient{scopes: scopes} ->
        scope in scopes

      _ ->
        false
    end
  end
end
