defmodule F1Bot.DelayedEvents.Rebroadcaster do
  use GenServer
  alias F1Bot.DelayedEvents
  alias F1Bot.Ets

  @ets_table_prefix "delayed_events"

  def start_link(options) do
    delay_ms = Keyword.fetch!(options, :delay_ms)

    options = %{
      delay_ms: delay_ms
    }

    GenServer.start_link(__MODULE__, options, name: server_via(delay_ms))
  end

  def server_via(delay_ms) do
    :"#{__MODULE__}::#{delay_ms}"
  end

  def fetch_latest_event(delay_ms, event_scope) do
    if delay_ms in DelayedEvents.available_delays() do
      delay_ms
      |> ets_table_name()
      |> Ets.fetch(to_string(event_scope))
    else
      {:error, :invalid_delay}
    end
  end

  def clear_cache(delay_ms) do
    delay_ms
    |> server_via()
    |> GenServer.call(:clear_cache)
  end

  @impl true
  def init(options) do
    {:ok, timer_ref} = :timer.send_interval(100, :rebroadcast)

    options.delay_ms
    |> ets_table_name()
    |> Ets.new()

    state =
      options
      |> Map.put(:event_queue, :gb_trees.empty())
      |> Map.put(:timer_ref, timer_ref)

    {:ok, state}
  end

  @impl true
  def handle_call(:clear_cache, _from, state) do
    state = %{state | event_queue: :gb_trees.empty()}

    state.delay_ms
    |> ets_table_name()
    |> Ets.clear()

    flush_mailbox()

    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:rebroadcast, state) do
    delay_ms = state.delay_ms
    now = F1Bot.Time.unix_timestamp_now(:millisecond)

    until_ts = now - delay_ms
    state = rebroadcast_batch(state, until_ts)

    {:noreply, state}
  end

  @impl true
  def handle_info({:events, events}, state) do
    event_queue =
      Enum.reduce(events, state.event_queue, fn event, event_queue ->
        :gb_trees.insert(event.sort_key, event, event_queue)
      end)

    state = %{state | event_queue: event_queue}

    {:noreply, state}
  end

  defp rebroadcast_batch(state, until_ts) do
    if :gb_trees.size(state.event_queue) == 0 do
      state
    else
      {sort_key, event, rest_event_q} = :gb_trees.take_smallest(state.event_queue)
      {ts, _} = sort_key

      if ts <= until_ts do
        save_latest_event(state, event)
        do_rebroadcast(state, event)

        state = %{state | event_queue: rest_event_q}
        rebroadcast_batch(state, until_ts)
      else
        state
      end
    end
  end

  defp do_rebroadcast(state, event) do
    topic = DelayedEvents.delayed_topic_for_event(event.scope, state.delay_ms)
    F1Bot.PubSub.broadcast(topic, event)
  end

  defp save_latest_event(state, event) do
    state.delay_ms
    |> ets_table_name()
    |> Ets.insert(to_string(event.scope), event)
  end

  defp flush_mailbox() do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end

  defp ets_table_name(delay_ms), do: :"#{@ets_table_prefix}_#{delay_ms}"
end
