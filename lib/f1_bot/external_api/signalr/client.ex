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

  # Must be a string, otherwise pattern matching won't work - server responds with a string
  @subscribe_command_id "0"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    %{
      data: negotiation_data,
      cookies: cookies
    } = do_negotiate_signalr_conn(opts)

    path = Keyword.fetch!(opts, :path)

    # Sanity check, make sure server doesn't want us to connect to a different path than originally specified
    ^path = Map.fetch!(negotiation_data, "Url")

    state =
      %{
        conn_pid: nil,
        stream_ref: nil,
        state: :disconnected,
        hostname: Keyword.fetch!(opts, :hostname) |> String.to_charlist(),
        port: Keyword.fetch!(opts, :port),
        path: path |> String.to_charlist(),
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
      |> do_connect_ws()

    {:ok, state}
  end

  @impl true
  def handle_info(
        {:gun_upgrade, conn_pid, stream_ref, ["websocket"], _headers},
        state = %{conn_pid: conn_pid, stream_ref: stream_ref}
      ) do
    Logger.info("Connection upgraded to websocket")
    state = do_initialize_signalr(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:gun_response, _conn_pid, _stream_ref, _is_fin, _status, _headers},
        state = %{state: :connecting_ws}
      ) do
    Logger.error("Server refused Websocket upgrade")
    {:stop, :server_refused_websocket, state}
  end

  @impl true
  def handle_info(
        {:gun_ws, _conn_pid, _stream_ref, {:text, "{}"}},
        state = %{state: :subscribed}
      ) do
    Logger.info("Received SignalR keep-alive")
    state = %{state | last_keepalive: DateTime.utc_now()}
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws, _conn_pid, _conn_ref, {:text, message}}, state) do
    message = Jason.decode!(message)
    state = maybe_update_client_state(state, message)

    if state.state == :subscribed do
      maybe_handle_subscription_message(state, message)
      maybe_handle_init_response(state, message)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        :signalr_subscribe_timeout,
        state = %{state: :awaiting_signalr_subscription}
      ) do
    {:stop, :signalr_handshake_timeout, state}
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

  @impl true
  def handle_info(
        {:gun_down, _pid, _proto, reason, _},
        state
      ) do
    {:stop, {:gun_down, reason}, state}
  end

  @impl true
  def handle_info(
        {:gun_error, _pid, reason},
        state
      ) do
    {:stop, {:gun_error, reason}, state}
  end

  defp send_ws_message(%{conn_pid: pid, stream_ref: ref}, message) when pid != nil do
    msg_json = Jason.encode!(message)
    :gun.ws_send(pid, ref, {:text, msg_json})
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
    Logger.info("Connecting to SignalR via websocket")

    if state.conn_pid != nil do
      :gun.close(state.conn_pid)
    end

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
      |> String.to_charlist()

    headers = [
      {"cookie", cookies_header}
    ]

    path = "#{state.path}/connect?#{query}"

    {:ok, pid} = :gun.open(state.hostname, state.port)
    {:ok, _} = :gun.await_up(pid, 2000)
    stream_ref = :gun.ws_upgrade(pid, path, headers)

    %{state | conn_pid: pid, stream_ref: stream_ref, state: :connecting_ws}
  end

  defp do_initialize_signalr(state) do
    topics_str = state.topics |> Enum.join(",")
    Logger.info("Initializing SignalR topics: #{topics_str}")

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
    :timer.send_after(1000, :signalr_subscribe_timeout)

    state = %{state | state: :awaiting_signalr_subscription}
    state
  end

  defp maybe_update_client_state(
         state = %{state: :awaiting_signalr_subscription},
         _message = %{"I" => @subscribe_command_id, "R" => current_data}
       ) do
    subscribed_topics =
      current_data
      |> Map.keys()
      |> Enum.join(",")

    Logger.info("SignalR status changed to subscribed. Topics: #{subscribed_topics}")
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

  defp maybe_handle_init_response(
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

  defp maybe_handle_init_response(_state, _message) do
    :ignore
  end

  defp process_packet(payload = %Packet{}) do
    options = %ProcessingOptions{
      ignore_reset: false,
      log_stray_packets: true,
    }
    F1Bot.F1Session.Server.process_live_timing_packet(payload, options)
  end
end
