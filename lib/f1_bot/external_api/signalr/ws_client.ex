defmodule F1Bot.ExternalApi.SignalR.WSClient do
  use Fresh, restart: :temporary
  require Logger

  alias F1Bot.ExternalApi.SignalR

  @impl Fresh
  def handle_connect(_status, _headers, state) do
    SignalR.Client.ws_handle_connected()
    {:ok, state}
  end

  @impl Fresh
  def handle_in(message, state) do
    # IO.inspect(message, label: "in")
    SignalR.Client.ws_handle_message(message)
    {:ok, state}
  end

  @impl Fresh
  def handle_error(error, _state) do
    Logger.error("SignalR connection error: #{inspect(error)}")

    {:close, {:error, error}}
  end

  @impl Fresh
  def handle_disconnect(code, reason, _state) do
    Logger.error("SignalR disconnected: #{inspect({code, reason})}")

    {:close, {:error, reason}}
  end

  def send(message) do
    # IO.inspect(message, label: "out")
    Fresh.send(__MODULE__, message)
  end

  def name, do: {:local, __MODULE__}
end
