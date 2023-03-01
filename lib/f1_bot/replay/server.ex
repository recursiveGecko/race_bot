defmodule F1Bot.Replay.Server do
  use GenServer
  require Logger
  alias F1Bot.F1Session.LiveTimingHandlers.ProcessingOptions
  alias F1Bot.Replay

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    state = %{
      url: nil,
      demo_mode: false,
      in_progress: false,
      initial_replay_state: nil,
      replay_state: nil,
      start_system_time: nil,
      start_replay_time: nil,
      tick_timer_ref: nil,
      playback_rate: 1
    }

    state =
      if F1Bot.demo_mode_url() != nil do
        start_demo_mode(state)
      else
        state
      end

    {:ok, state}
  end

  def start_replay(url, playback_rate \\ 1) do
    GenServer.call(__MODULE__, {:start_replay, url, playback_rate}, 60_000)
  end

  def stop_replay() do
    GenServer.call(__MODULE__, :stop_replay)
  end

  def fast_forward(seconds) when is_integer(seconds) and seconds > 0 do
    GenServer.call(__MODULE__, {:fast_forward_ms, seconds * 1000})
  end

  @impl true
  def handle_call({:start_replay, url, playback_rate}, _from, state) do
    if state.in_progress do
      {:reply, {:error, :replay_in_progress}, state}
    else
      state =
        state
        |> put_in([:playback_rate], playback_rate)
        |> initialize_replay(url)
        |> skip_to_start_and_start_playing()

      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:stop_replay, _from, state) do
    if state.in_progress do
      state = stop_ticks(state)

      {:reply, :ok, state}
    else
      {:reply, {:error, :no_replay_in_progress}, state}
    end
  end

  @impl true
  def handle_call({:fast_forward_ms, offset_ms}, _from, state) do
    if state.in_progress do
      state = sync_time(state, offset_ms)
      {:reply, :ok, state}
    else
      {:reply, {:error, :no_replay_in_progress}, state}
    end
  end

  @impl true
  def handle_info(:replay_tick, state) do
    if state.in_progress do
      state =
        state
        |> replay_chunk()
        |> maybe_handle_replay_end()

      {:noreply, state}
    else
      {:noreply, state}
    end
  end

  defp start_demo_mode(state) do
    state
    |> Map.put(:demo_mode, true)
    |> initialize_replay(F1Bot.demo_mode_url())
    |> skip_to_start_and_start_playing()
  end

  defp initialize_replay(state, url) do
    options = %Replay.Options{
      report_progress: true,
      packets_fn: fn _replay_state, _options, _packet ->
        raise "We will never reach this point because the replay will be paused immediately"
      end,
      replay_while_fn: fn _replay_state, _packet, _ts_ms ->
        false
      end
    }

    {:ok, replay_state} = Replay.start_replay(url, options)

    %{state | url: url, initial_replay_state: replay_state, replay_state: replay_state}
    |> sync_time()
  end

  defp skip_to_start_and_start_playing(state) do
    # Manually reset the session. The automatic reset logic won't
    # work for replays as the session name and type don't change.
    F1Bot.F1Session.Server.reset_session()
    F1Bot.F1Session.Server.set_local_time_mode(:last_packet, state.playback_rate)

    state
    |> fast_forward_to_session_start()
    |> schedule_ticks()
  end

  defp fast_forward_to_session_start(state) do
    options = %Replay.Options{
      report_progress: true,
      packets_fn: fn replay_state, _options, packet ->
        processing_options = %ProcessingOptions{
          ignore_reset: true,
          log_stray_packets: true,
          local_time_fn: fn -> packet.timestamp end
        }

        F1Bot.F1Session.Server.process_live_timing_packet(packet, processing_options)
        replay_state
      end,
      replay_while_fn: fn _replay_state, packet, _ts_ms ->
        not match?(%{topic: "SessionStatus", data: %{"Status" => "Started"}}, packet)
      end
    }

    replay_state = Replay.replay_dataset(state.replay_state, options)
    # Force session sync events because the session change detection
    # logic is unreliable in demo mode with the same session repeating.
    F1Bot.resync_state_events()

    %{state | replay_state: replay_state}
    |> sync_time()
  end

  defp sync_time(state, offset_ms \\ 0) do
    %{dataset: [next_msg | _]} = state.replay_state
    {ts_ms, _file_name, _session_ts, _payload} = next_msg

    %{
      state
      | start_system_time: System.monotonic_time(:millisecond) - offset_ms,
        start_replay_time: ts_ms
    }
  end

  defp replay_chunk(state = %{replay_state: replay_state}) do
    now_system_ms = System.monotonic_time(:millisecond)
    start_system_ms = state.start_system_time
    start_replay_ms = state.start_replay_time
    rate = state.playback_rate

    max_replay_ms = rate * (now_system_ms - start_system_ms) + start_replay_ms

    options = %Replay.Options{
      report_progress: true,
      packets_fn: fn replay_state, _options, packet ->
        processing_options = %ProcessingOptions{
          ignore_reset: true,
          log_stray_packets: true,
          local_time_fn: fn -> packet.timestamp end
        }

        F1Bot.F1Session.Server.process_live_timing_packet(packet, processing_options)
        replay_state
      end,
      replay_while_fn: fn _replay_state, _packet, ts_ms ->
        ts_ms < max_replay_ms
      end
    }

    # Prevent server crashes in development when code is recompiled and module is temporarily unloaded
    replay_state =
      try do
        Replay.replay_dataset(replay_state, options)
      rescue
        e ->
          Logger.error("Error replaying chunk: #{inspect(e)}")
          replay_state
      end

    %{state | replay_state: replay_state}
  end

  defp maybe_handle_replay_end(state) do
    if state.replay_state.dataset == [] do
      Logger.info("[Replay Server] Replay completed.")
      F1Bot.F1Session.Server.set_local_time_mode(:real)
      state = stop_ticks(state)

      if state.demo_mode do
        Logger.info("[Replay Server] Demo mode enabled, restarting.")
        restart_from_initial(state)
      else
        state
      end
    else
      state
    end
  end

  defp restart_from_initial(state) do
    state
    |> Map.put(:replay_state, state.initial_replay_state)
    |> skip_to_start_and_start_playing()
  end

  defp schedule_ticks(state) do
    timer_ref = :timer.send_interval(100, :replay_tick)
    %{state | in_progress: true, tick_timer_ref: timer_ref}
  end

  defp stop_ticks(state) do
    state = %{state | in_progress: false}

    if state.tick_timer_ref do
      :timer.cancel(state.tick_timer_ref)
      %{state | tick_timer_ref: nil}
    else
      state
    end
  end
end
