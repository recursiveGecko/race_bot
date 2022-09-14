defmodule F1Bot.Replay.Server do
  use GenServer
  require Logger

  @speed_modifier 1

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    state = %{
      url: nil,
      demo_mode: nil,
      in_progress: false,
      initial_replay_state: nil,
      replay_state: nil,
      start_system_time: nil,
      start_replay_time: nil,
      tick_timer_ref: nil
    }

    state =
      if F1Bot.demo_mode_url() != nil do
        state
        |> Map.put(:demo_mode, true)
        |> initialize_replay(F1Bot.demo_mode_url())
        |> skip_to_start_and_start_playing()
      else
        %{state | demo_mode: false}
      end

    {:ok, state}
  end

  def start_replay(url) do
    GenServer.call(__MODULE__, {:start_replay, url}, 60_000)
  end

  def stop_replay() do
    GenServer.call(__MODULE__, :stop_replay)
  end

  @impl true
  def handle_call({:start_replay, url}, _from, state) do
    if state.in_progress do
      {:reply, {:error, :replay_in_progress}, state}
    else
      state =
        state
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

  defp skip_to_start_and_start_playing(state) do
    # Manually reset the session. The automatic reset logic won't
    # work for replays as the session name and type don't change.
    F1Bot.F1Session.Server.reset_session()

    state
    |> fast_forward_to_session_start()
    |> schedule_ticks()
  end

  defp initialize_replay(state, url) do
    options = %{
      report_progress: true,
      packets_fn: &handle_packet/3,
      replay_while_fn: fn _replay_state, _packet, _ts_ms ->
        false
      end
    }

    {:ok, replay_state} = F1Bot.Replay.start_replay(url, options)

    %{state | url: url, initial_replay_state: replay_state, replay_state: replay_state}
    |> sync_time()
  end

  defp fast_forward_to_session_start(state) do
    options = %{
      report_progress: true,
      packets_fn: &handle_packet/3,
      replay_while_fn: fn _replay_state, packet, _ts_ms ->
        not match?(%{topic: "SessionStatus", data: %{"Status" => "Started"}}, packet)
      end
    }

    replay_state = F1Bot.Replay.replay_dataset(state.replay_state, options)

    %{state | replay_state: replay_state}
    |> sync_time()
  end

  defp sync_time(state) do
    %{dataset: [next_msg | _]} = state.replay_state
    {ts_ms, _file_name, _session_ts, _payload} = next_msg

    %{
      state
      | start_system_time: System.monotonic_time(:millisecond),
        start_replay_time: ts_ms
    }
  end

  defp replay_chunk(state = %{replay_state: replay_state}) do
    max_ms =
      @speed_modifier * (System.monotonic_time(:millisecond) - state.start_system_time) +
        state.start_replay_time

    options = %{
      report_progress: true,
      packets_fn: &handle_packet/3,
      replay_while_fn: fn _replay_state, _packet, ts_ms ->
        ts_ms < max_ms
      end
    }

    replay_state = F1Bot.Replay.replay_dataset(replay_state, options)

    %{state | replay_state: replay_state}
  end

  defp handle_packet(replay_state, _options, packet) do
    F1Bot.F1Session.Server.push_live_timing_packet(packet)
    replay_state
  end

  defp maybe_handle_replay_end(state) do
    if state.replay_state.dataset == [] do
      Logger.info("[Replay Server] Replay completed.")
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
