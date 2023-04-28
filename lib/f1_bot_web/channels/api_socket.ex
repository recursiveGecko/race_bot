defmodule F1BotWeb.ApiSocket do
  use Phoenix.Socket
  require Logger

  alias F1Bot.Authentication
  alias F1Bot.Authentication.ApiClient

  channel("transcriber_service", F1BotWeb.TranscriberServiceChannel)

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error` or `{:error, term}`. To control the
  # response the client receives in that case, [define an error handler in the
  # websocket
  # configuration](https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#socket/3-websocket-configuration).
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(params, socket, _connect_info) do
    with {:ok, socket} <- authorized?(socket, params) do
      {:ok, socket}
    end
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.F1BotWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket), do: "api_client_socket:#{socket.assigns.authenticated_api_client.client_name}"

  def authorized?(socket, params) do
    with %{"token" => token} <- params,
         [client_name, client_secret] <- String.split(token, ":", parts: 2),
         {:ok, client} <- Authentication.find_api_client_by_name(client_name),
         true <- ApiClient.verify_secret(client, client_secret) do
      {:ok, assign(socket, :authenticated_api_client, client)}
    else
      %{} ->
        Logger.warn("ApiSocket: Missing token")
        {:error, :missing_token}

      parts = [_ | _] ->
        Logger.warn("ApiSocket: Invalid token format (#{length(parts)} parts)")
        {:error, :invalid_token_format}

      {:error, :not_found} ->
        Logger.warn("ApiSocket: Invalid client name")
        {:error, :unauthorized}

      false ->
        Logger.warn("ApiSocket: Invalid client secret")
        {:error, :unauthorized}

      e ->
        Logger.warn("ApiSocket: Unknown error #{inspect(e)}")
        {:error, :unauthorized}
    end
  end
end
