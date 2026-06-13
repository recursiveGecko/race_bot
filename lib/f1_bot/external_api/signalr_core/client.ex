defmodule F1Bot.ExternalApi.SignalRCore.Client do
  @moduledoc """
  A SignalR client that establishes a websocket connection to the F1 live timing API and handles
  all received events by forming `F1Bot.F1Session.LiveTimingHandlers.Packet` structs and passing them to
  `F1Bot.F1Session.LiveTimingHandlers` for processing.

  As of 2026 F1 uses ASP.NET Core SignalR (`/signalrcore`). The JSON hub protocol works as follows:

    1. HTTP POST `/signalrcore/negotiate?negotiateVersion=1` -> connectionToken + AWSALB cookie
    2. Open websocket `wss://.../signalrcore?id=<connectionToken>`
    3. Send handshake `{"protocol":"json","version":1}\x1e`
    4. Receive handshake ack `{}\x1e`
    5. Invoke `{"type":1,"target":"Subscribe","arguments":[[topics]],"invocationId":"0"}\x1e`
    6. Receive completion `{"type":3,"invocationId":"0","result":{<snapshot>}}\x1e` (initial state)
    7. Receive feed `{"type":1,"target":"feed","arguments":[topic, data, timestamp]}\x1e`
    8. Server/client keep-alive pings `{"type":6}\x1e`

  Each message is terminated by the ASCII record separator 0x1e; a single websocket
  frame may contain several concatenated messages.

  https://github.com/dotnet/aspnetcore/blob/main/src/SignalR/docs/specs/HubProtocol.md
  """
  use GenServer
  require Logger
  alias F1Bot.ExternalApi.SignalRCore
  alias F1Bot.F1Session.LiveTimingHandlers.{Packet, ProcessingOptions}

  @supervisor F1Bot.DynamicSupervisor

  # SignalR Core message terminator (ASCII record separator, 0x1e)
  @rs "\x1e"

  # Must be a string, otherwise pattern matching won't work - server echoes it back as a string
  @subscribe_command_id "0"

  # No KeepAliveTimeout is provided by the Core negotiate response. The server pings
  # roughly every 15s by default; allow a generous window before assuming a dead link.
  @keepalive_timeout_sec 30

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def ws_handle_connected() do
    GenServer.call(__MODULE__, {:ws_handle_connected})
  end

  def ws_handle_message(message) do
    GenServer.call(__MODULE__, {:ws_handle_message, message})
  end

  @impl true
  def init(opts) do
    {:ok, nil, {:continue, {:after_init, opts}}}
  end

  @impl true
  def handle_continue({:after_init, opts}, _state) do
    Logger.info("SignalR: Sleeping for 2 seconds")
    Process.sleep(2000)

    %{
      data: negotiation_data,
      cookies: cookies
    } = do_negotiate_signalr_conn(opts)

    state =
      %{
        ws_client_pid: nil,
        state: :disconnected,
        hostname: Keyword.fetch!(opts, :hostname),
        scheme: Keyword.fetch!(opts, :scheme),
        port: Keyword.fetch!(opts, :port),
        base_path: Keyword.fetch!(opts, :base_path),
        user_agent: Keyword.fetch!(opts, :user_agent),
        signalr_params: %{
          conn_id: Map.fetch!(negotiation_data, "ConnectionId"),
          conn_token: Map.fetch!(negotiation_data, "ConnectionToken"),
          cookies: cookies
        },
        hub: Keyword.fetch!(opts, :hub),
        topics: Keyword.fetch!(opts, :topics),
        last_keepalive: nil,
        keepalive_timeout: @keepalive_timeout_sec
      }

    state = do_connect_ws(state)
    {:noreply, state}
  end

  @impl true
  def handle_call({:ws_handle_connected}, _from, state) do
    Logger.info("SignalR: Connected to websocket")

    state = do_send_handshake(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:ws_handle_message, message}, _from, state) do
    state = do_handle_message(message, state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:send_ping, state = %{state: :subscribed}) do
    send_ws_message(%{type: 6})
    {:noreply, state}
  end

  def handle_info(:send_ping, state), do: {:noreply, state}

  @impl true
  def handle_info(
        :signalr_init_timeout,
        state = %{state: :awaiting_handshake}
      ) do
    {:stop, :signalr_init_timeout, state}
  end

  def handle_info(
        :signalr_init_timeout,
        state = %{state: _anything}
      ) do
    {:noreply, state}
  end

  @impl true
  def handle_info(
        :signalr_subscribe_timeout,
        state = %{state: :awaiting_signalr_subscription}
      ) do
    {:stop, :signalr_subscribe_timeout, state}
  end

  def handle_info(
        :signalr_subscribe_timeout,
        state = %{state: _anything}
      ) do
    {:noreply, state}
  end

  @impl true
  def handle_info(
        :check_keepalive,
        state = %{last_keepalive: last_keepalive, keepalive_timeout: timeout}
      ) do
    then_sec = DateTime.to_unix(last_keepalive)

    now_sec =
      DateTime.utc_now()
      |> DateTime.to_unix()

    sec_since_keepalive = now_sec - then_sec

    if sec_since_keepalive > timeout do
      {:stop, :keepalive_timeout, state}
    else
      {:noreply, state}
    end
  end

  defp do_negotiate_signalr_conn(opts) do
    {:ok, negotiation_data} = SignalRCore.Negotiation.negotiate(opts)
    negotiation_data
  end

  defp do_connect_ws(state) do
    # SignalR Core uses the negotiated connectionToken as the `id` query param.
    query =
      %{id: state.signalr_params.conn_token}
      |> URI.encode_query()

    cookies_header =
      state.signalr_params.cookies
      |> Enum.map_join("; ", fn {name, val} -> "#{name}=#{val}" end)

    headers = [
      {"cookie", cookies_header},
      {"user-agent", state.user_agent}
    ]

    ws_scheme =
      case state.scheme do
        "https" -> "wss"
        "http" -> "ws"
      end

    uri = "#{ws_scheme}://#{state.hostname}:#{state.port}#{state.base_path}?#{query}"
    ws_state = %{client_pid: self()}
    ws_opts = [name: SignalRCore.WSClient.name(), headers: headers]

    Logger.info("SignalR: Connecting to websocket at '#{uri}'")

    {:ok, ws_client_pid} =
      DynamicSupervisor.start_child(
        @supervisor,
        {SignalRCore.WSClient, [uri: uri, state: ws_state, opts: ws_opts]}
      )

    Process.link(ws_client_pid)
    Logger.info("SignalR: Client started at #{inspect(ws_client_pid)}")

    %{state | ws_client_pid: ws_client_pid, state: :connecting_ws}
  end

  # SignalR Core: send the protocol handshake immediately after the socket opens.
  defp do_send_handshake(state) do
    send_ws_message(%{protocol: "json", version: 1})
    :timer.send_after(5000, :signalr_init_timeout)
    %{state | state: :awaiting_handshake}
  end

  defp do_subscribe_signalr(state) do
    topics_str = state.topics |> Enum.join(",")
    Logger.info("SignalR: Subscribing to topics: #{topics_str}")

    msg = %{
      type: 1,
      target: "Subscribe",
      arguments: [state.topics],
      invocationId: @subscribe_command_id
    }

    send_ws_message(msg)
    :timer.send_after(5000, :signalr_subscribe_timeout)

    %{state | state: :awaiting_signalr_subscription}
  end

  defp send_ws_message(message) do
    # Each SignalR Core message is terminated by the 0x1e record separator.
    json = Jason.encode!(message) <> @rs
    SignalRCore.WSClient.send({:text, json})
  end

  # A single websocket text frame may bundle several 0x1e-separated messages.
  defp do_handle_message({:text, raw}, state) do
    raw
    |> String.split(@rs, trim: true)
    |> Enum.reduce(state, &handle_frame/2)
  end

  defp do_handle_message(_other, state), do: state

  defp handle_frame(frame, state) do
    case Jason.decode(frame) do
      {:ok, data} -> dispatch_message(data, state)
      {:error, _} -> state
    end
  end

  # Handshake acknowledgement: an empty object (`{}`) means success.
  defp dispatch_message(data, state = %{state: :awaiting_handshake})
       when map_size(data) == 0 do
    Logger.info("SignalR: handshake complete")
    do_subscribe_signalr(state)
  end

  defp dispatch_message(%{"error" => err}, state = %{state: :awaiting_handshake}) do
    Logger.error("SignalR: handshake rejected: #{inspect(err)}")
    state
  end

  # Keep-alive ping (type 6) from the server.
  defp dispatch_message(%{"type" => 6}, state) do
    %{state | last_keepalive: DateTime.utc_now()}
  end

  # Completion of the Subscribe invocation (type 3) carries the initial snapshot.
  defp dispatch_message(
         %{"type" => 3, "invocationId" => @subscribe_command_id} = msg,
         state
       ) do
    results = Map.get(msg, "result") || %{}

    for {topic, data} <- results do
      payload = %Packet{
        topic: topic,
        data: data,
        timestamp: nil,
        init: true
      }

      process_packet(payload)
    end

    subscribed_topics = results |> Map.keys() |> Enum.join(",")
    Logger.info("SignalR: status changed to subscribed. Topics: #{subscribed_topics}")

    :timer.send_interval(1000, :check_keepalive)
    :timer.send_interval(10_000, :send_ping)

    %{state | state: :subscribed, last_keepalive: DateTime.utc_now()}
  end

  # Live feed message (type 1, target "feed").
  defp dispatch_message(
         %{"type" => 1, "target" => "feed", "arguments" => arguments},
         state
       ) do
    [topic, data, timestamp | _] = arguments

    topic = String.trim_trailing(topic, ".z")
    timestamp = F1Bot.DataTransform.Parse.parse_iso_timestamp(timestamp)

    payload = %Packet{
      topic: topic,
      data: data,
      timestamp: timestamp
    }

    Logger.debug("Received data on topic #{topic}")
    process_packet(payload)

    %{state | last_keepalive: DateTime.utc_now()}
  end

  # Server requested the connection be closed (type 7).
  defp dispatch_message(%{"type" => 7} = msg, state) do
    Logger.warning("SignalR: server closed the connection: #{inspect(msg)}")
    state
  end

  defp dispatch_message(_message, state), do: state

  defp process_packet(payload = %Packet{}) do
    options = %ProcessingOptions{
      ignore_reset: false,
      log_stray_packets: true
    }

    F1Bot.F1Session.Server.process_live_timing_packet(payload, options)
  end
end
