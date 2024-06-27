defmodule F1Bot.ExternalApi.SignalR.Client do
  @moduledoc """
  A signalR client that establishes a websocket connection to the live timing API and handles
  all received events by forming `F1Bot.F1Session.LiveTimingHandlers.Packet` structs and passing them to
  `F1Bot.F1Session.LiveTimingHandlers` for processing.

  Useful documentation for SignalR 1.2:
  https://blog.3d-logic.com/2015/03/29/signalr-on-the-wire-an-informal-description-of-the-signalr-protocol/

  https://learn.microsoft.com/en-us/aspnet/core/signalr/introduction
  https://github.com/SignalR/SignalR/blob/f3600c71f83d8312ad61bced0ca547795734d51e/src/Microsoft.AspNet.SignalR.Client/Connection.cs
  https://github.com/SignalR/SignalR/blob/f3600c71f83d8312ad61bced0ca547795734d51e/src/Microsoft.AspNet.SignalR.Client/Transports/TransportHelper.cs
  """
  use GenServer
  require Logger
  alias F1Bot.ExternalApi.SignalR
  alias F1Bot.F1Session.LiveTimingHandlers.{Packet, ProcessingOptions}

  @supervisor F1Bot.DynamicSupervisor

  # Must be a string, otherwise pattern matching won't work - server responds with a string
  @subscribe_command_id "0"

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

    base_path = Keyword.fetch!(opts, :base_path)

    # Sanity check, make sure server doesn't want us to connect to a different path than originally specified
    ^base_path = Map.fetch!(negotiation_data, "Url")

    state =
      %{
        ws_client_pid: nil,
        state: :disconnected,
        hostname: Keyword.fetch!(opts, :hostname),
        scheme: Keyword.fetch!(opts, :scheme),
        port: Keyword.fetch!(opts, :port),
        base_path: base_path,
        user_agent: Keyword.fetch!(opts, :user_agent),
        signalr_params: %{
          conn_id: Map.fetch!(negotiation_data, "ConnectionId"),
          conn_token: Map.fetch!(negotiation_data, "ConnectionToken"),
          conn_data: make_conn_data(opts),
          cookies: cookies
        },
        hub: Keyword.fetch!(opts, :hub),
        topics: Keyword.fetch!(opts, :topics),
        negotiation_data: negotiation_data,
        last_keepalive: nil,
        keepalive_timeout: Map.fetch!(negotiation_data, "KeepAliveTimeout")
      }

    state = do_connect_ws(state)
    {:noreply, state}
  end

  @impl true
  def handle_call({:ws_handle_connected}, _from, state) do
    Logger.info("SignalR: Connected to websocket")

    state = do_await_signalr_init(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:ws_handle_message, message}, _from, state) do
    state = do_handle_message(message, state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(
        :signalr_init_timeout,
        state = %{state: :awaiting_signalr_init}
      ) do
    {:stop, :signalr_init_timeout, state}
  end

  @impl true
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

  @impl true
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
    extra_negotiation_opts = [conn_data: make_conn_data(opts)]

    negotiation_opts = Keyword.merge(opts, extra_negotiation_opts)
    {:ok, negotiation_data} = SignalR.Negotiation.negotiate(negotiation_opts)

    negotiation_data
  end

  defp make_conn_data(opts) do
    [%{name: Keyword.fetch!(opts, :hub)}]
  end

  defp do_connect_ws(state) do
    query =
      %{
        transport: "webSockets",
        clientProtocol: "1.2",
        connectionToken: state.signalr_params.conn_token,
        connectionData: state.signalr_params.conn_data |> Jason.encode!()
      }
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

    uri = "#{ws_scheme}://#{state.hostname}:#{state.port}#{state.base_path}/connect?#{query}"
    ws_state = %{client_pid: self()}
    ws_opts = [name: SignalR.WSClient.name(), headers: headers]

    Logger.info("SignalR: Connecting to websocket at '#{uri}'")

    {:ok, ws_client_pid} =
      DynamicSupervisor.start_child(
        @supervisor,
        {SignalR.WSClient, [uri: uri, state: ws_state, opts: ws_opts]}
      )

    Process.link(ws_client_pid)
    Logger.info("SignalR: Client started at #{inspect(ws_client_pid)}")

    %{state | ws_client_pid: ws_client_pid, state: :connecting_ws}
  end

  defp do_handle_message(_message = {:text, "{}"}, state) do
    Logger.debug("SignalR: Received keep-alive")
    %{state | last_keepalive: DateTime.utc_now()}
  end

  defp do_handle_message(_message = {:text, json}, state) do
    data = Jason.decode!(json)
    state = maybe_update_client_state(state, data)

    if state.state == :subscribed do
      maybe_handle_subscribe_response(state, data)
      maybe_handle_subscription_message(state, data)
    end

    state
  end

  defp send_ws_message(_state, message) do
    json = Jason.encode!(message)
    SignalR.WSClient.send({:text, json})
  end

  # Set up a timer that waits for the first message to be sent by the server, indicating successful connection
  defp do_await_signalr_init(state) do
    :timer.send_after(3000, :signalr_init_timeout)
    %{state | state: :awaiting_signalr_init}
  end

  defp do_subscribe_signalr(state) do
    topics_str = state.topics |> Enum.join(",")
    Logger.info("SignalR: Subscribing to topics: #{topics_str}")

    msg = %{
      # Reverse engineered from official app
      H: state.hub,
      # Reverse engineered from official app
      M: "Subscribe",
      # Reverse engineered from official app
      A: [state.topics],
      # Can be anything, likely an auto-incrementing per-connection ID of messages
      I: @subscribe_command_id
    }

    send_ws_message(state, msg)
    :timer.send_after(3000, :signalr_subscribe_timeout)

    %{state | state: :awaiting_signalr_subscription}
  end

  defp maybe_update_client_state(
         state = %{state: :awaiting_signalr_init},
         _message = %{"C" => _, "S" => 1}
       ) do
    Logger.info("SignalR: connection initialized")
    do_subscribe_signalr(state)
  end

  defp maybe_update_client_state(
         state = %{state: :awaiting_signalr_subscription},
         _message = %{"I" => @subscribe_command_id, "R" => current_data}
       ) do
    subscribed_topics =
      current_data
      |> Map.keys()
      |> Enum.join(",")

    Logger.info("SignalR: status changed to subscribed. Topics: #{subscribed_topics}")
    :timer.send_interval(1000, :check_keepalive)
    %{state | state: :subscribed, last_keepalive: DateTime.utc_now()}
  end

  defp maybe_update_client_state(state, _message), do: state

  defp maybe_handle_subscription_message(
         _state,
         _message = %{"M" => messages}
       ) do
    for m <- messages do
      # method is "feed"
      # method = Map.fetch!(m, "M")
      [topic, data, timestamp | _] = Map.fetch!(m, "A")

      topic = String.trim_trailing(topic, ".z")

      timestamp = F1Bot.DataTransform.Parse.parse_iso_timestamp(timestamp)

      payload = %Packet{
        topic: topic,
        data: data,
        timestamp: timestamp
      }

      Logger.debug("Received data on topic #{topic}")

      process_packet(payload)
    end
  end

  defp maybe_handle_subscription_message(_state, _message) do
    # IO.inspect(message)
    :ignore
  end

  defp maybe_handle_subscribe_response(
         _state,
         _message = %{"R" => results, "I" => @subscribe_command_id}
       ) do
    for {topic, data} <- results do
      payload = %Packet{
        topic: topic,
        data: data,
        timestamp: nil,
        init: true
      }

      process_packet(payload)
    end
  end

  defp maybe_handle_subscribe_response(_state, _message) do
    :ignore
  end

  defp process_packet(payload = %Packet{}) do
    options = %ProcessingOptions{
      ignore_reset: false,
      log_stray_packets: true
    }

    F1Bot.F1Session.Server.process_live_timing_packet(payload, options)
  end
end
