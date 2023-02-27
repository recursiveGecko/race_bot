defmodule F1Bot.F1Session.Server do
  @moduledoc """
  GenServer that holds the live `F1Bot.F1Session` instance, acts as an entrypoint for
  incoming live timing packets and executes all side effects by passing event messages to
  `F1Bot.Output.Discord` and `F1Bot.Output.Twitter` via PubSub.
  """
  use GenServer
  require Logger

  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers
  alias F1Bot.F1Session.LiveTimingHandlers.{Packet, ProcessingOptions, ProcessingResult}
  alias F1Bot.PubSub
  alias F1Bot.DelayedEvents

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: server_via())
  end

  @impl true
  def init(_init_arg) do
    state = %{
      session: F1Session.new(),
      tick_interval_ref: :timer.send_interval(50, :periodic_tick)
    }

    {:ok, state}
  end

  def state(light_copy) when is_boolean(light_copy) do
    server_via()
    |> GenServer.call({:state, light_copy})
  end

  def resync_state_events() do
    server_via()
    |> GenServer.call({:resync_state_events})
  end

  def session_best_stats() do
    server_via()
    |> GenServer.call(:session_best_stats)
  end

  def session_info() do
    server_via()
    |> GenServer.call({:session_info})
  end

  def session_status() do
    server_via()
    |> GenServer.call({:session_status})
  end

  def driver_list() do
    server_via()
    |> GenServer.call({:driver_list})
  end

  def driver_summary(driver_no) do
    server_via()
    |> GenServer.call({:driver_summary, driver_no})
  end

  def driver_info_by_number(driver_number) when is_integer(driver_number) do
    server_via()
    |> GenServer.call({:driver_info_by_number, driver_number})
  end

  def driver_info_by_abbr(driver_abbr) when is_binary(driver_abbr) do
    server_via()
    |> GenServer.call({:driver_info_by_abbr, driver_abbr})
  end

  def driver_session_data(driver_number) when is_integer(driver_number) do
    server_via()
    |> GenServer.call({:driver_session_data, driver_number})
  end

  def track_status_history() do
    server_via()
    |> GenServer.call({:track_status_history})
  end

  def process_live_timing_packet(
        packet = %LiveTimingHandlers.Packet{},
        processing_options = %ProcessingOptions{}
      ) do
    server_via()
    |> GenServer.call({:process_live_timing_packet, packet, processing_options})
  end

  def replace_session(session = %F1Session{}) do
    server_via()
    |> GenServer.call({:replace_session, session})
  end

  def reset_session() do
    server_via()
    |> GenServer.call({:reset_session})
  end

  def session_clock_from_local_time(local_time) do
    server_via()
    |> GenServer.call({:session_clock_from_local_time, local_time})
  end

  @impl true
  def handle_call({:state, light_copy}, _from, state = %{session: session}) do
    reply =
      if light_copy do
        F1Bot.LightCopy.light_copy(session)
      else
        session
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:resync_state_events}, _from, state = %{session: session}) do
    events = F1Session.make_state_sync_events(session)
    PubSub.broadcast_events(events)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:session_best_stats, _from, state = %{session: session}) do
    reply = F1Session.session_best_stats(session)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:session_info}, _from, state = %{session: session}) do
    reply =
      case session.session_info.type do
        nil -> {:error, :no_session_info}
        _ -> {:ok, session.session_info}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:session_status}, _from, state = %{session: session}) do
    reply =
      case session.session_status do
        nil -> {:error, :not_available}
        status -> {:ok, status}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:driver_list}, _from, state = %{session: session}) do
    reply = F1Session.driver_list(session)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:driver_summary, driver_no}, _from, state = %{session: session}) do
    reply = F1Session.driver_summary(session, driver_no)

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:driver_info_by_number, driver_number}, _from, state = %{session: session}) do
    reply = F1Session.driver_info_by_number(session, driver_number)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:driver_info_by_abbr, driver_number}, _from, state = %{session: session}) do
    reply = F1Session.driver_info_by_abbr(session, driver_number)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:driver_session_data, driver_number}, _from, state = %{session: session}) do
    reply = F1Session.driver_session_data(session, driver_number)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:track_status_history}, _from, state = %{session: session}) do
    reply = session.track_status_history
    {:reply, reply, state}
  end

  @impl true
  def handle_call(
        {:process_live_timing_packet, packet, processing_options},
        _from,
        state = %{session: session}
      ) do
    options =
      %ProcessingOptions{
        log_stray_packets: true
      }
      |> ProcessingOptions.merge(processing_options)

    {session, events, do_reset_session} =
      try do
        reply = LiveTimingHandlers.process_live_timing_packet(session, packet, options)

        case reply do
          {:ok, result = %ProcessingResult{}} ->
            after_live_timing_packet(packet, result.session)
            {result.session, result.events, result.reset_session}

          e ->
            Logger.warn("Unable to process live timing packet: #{inspect(e)}")
            {session, [], false}
        end
      rescue
        e ->
          err_text = Exception.format(:error, e, __STACKTRACE__)
          Logger.error("Rescued an error while processing live timing packet: #{err_text}")
          Logger.error("Stacktrace: \n#{Exception.format_stacktrace(__STACKTRACE__)}")

          {session, [], false}
      end

    if do_reset_session do
      DelayedEvents.clear_all_caches()
    else
      PubSub.broadcast_events(events)
    end

    state = %{state | session: session}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:replace_session, session}, _from, state) do
    state = %{state | session: session}
    events = F1Session.make_state_sync_events(session)
    DelayedEvents.clear_all_caches()
    PubSub.broadcast_events(events)

    Logger.info("Session replaced!")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:reset_session}, _from, state) do
    # Ensure all session reset events are sent
    {session, events} = F1Session.reset_session(state.session)
    DelayedEvents.clear_all_caches()
    PubSub.broadcast_events(events)

    state = %{state | session: session}
    Logger.info("Session reset!")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(
        {:session_clock_from_local_time, local_time},
        _from,
        state = %{session: session}
      ) do
    reply = F1Session.session_clock_from_local_time(session, local_time)
    {:reply, reply, state}
  end

  @impl true
  def handle_info(:periodic_tick, state = %{session: session}) do
    # Prevent server crashes in development when code is recompiled and module is temporarily unloaded
    try do
      {session, events} = F1Session.periodic_tick(session)
      PubSub.broadcast_events(events)

      state = %{state | session: session}
      {:noreply, state}
    rescue
      _e ->
        Logger.error("Rescued an error in periodic tick")
        Logger.error("Stacktrace: \n#{Exception.format_stacktrace(__STACKTRACE__)}")

        {:noreply, state}
    end
  end

  defp after_live_timing_packet(_packet = %Packet{topic: "SessionInfo"}, session) do
    Logger.info("Session info updated: #{inspect(session.session_info, pretty: true)}")
  end

  defp after_live_timing_packet(_packet = %Packet{topic: "SessionStatus"}, session) do
    Logger.info("Session status updated: #{inspect(session.session_status)}")
  end

  defp after_live_timing_packet(_packet, _session), do: :skip

  def server_via() do
    __MODULE__
  end
end
