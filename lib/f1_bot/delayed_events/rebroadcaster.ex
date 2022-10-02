defmodule F1Bot.DelayedEvents.Rebroadcaster do
  use GenServer
  alias F1Bot.DelayedEvents
  alias F1Bot.Ets

  @ets_table_prefix :delayed_events

  def start_link(options) do
    delay_ms = Keyword.fetch!(options, :delay_ms)
    topic_pairs = Keyword.fetch!(options, :topic_pairs)

    options = %{
      delay_ms: delay_ms,
      topic_pairs: topic_pairs
    }

    GenServer.start_link(__MODULE__, options, name: :"#{__MODULE__}::#{delay_ms}")
  end

  def fetch_latest_event(delay_ms, event_scope, event_type) do
    delay_ms
    |> ets_table_name()
    |> Ets.fetch({atom(event_scope), atom(event_type)})
  end

  @impl true
  def init(options) do
    options.topic_pairs
    |> Enum.map(fn {scope, type} -> F1Bot.PubSub.topic_for_event(scope, type) end)
    |> F1Bot.PubSub.subscribe_all()

    {:ok, timer_ref} = :timer.send_interval(100, :rebroadcast)

    options.delay_ms
    |> ets_table_name()
    |> Ets.new()

    state =
      options
      |> Map.put(:events, [])
      |> Map.put(:timer_ref, timer_ref)

    {:ok, state}
  end

  @impl true
  def handle_info(:rebroadcast, state) do
    delay_ms = state.delay_ms
    now = System.monotonic_time(:millisecond)

    state =
      Enum.reduce_while(state.events, state, fn event, state ->
        rebroadcast? = event.timestamp + delay_ms <= now

        if rebroadcast? do
          delay_ms
          |> ets_table_name()
          |> Ets.insert({atom(event.scope), atom(event.type)}, event)

          state = do_rebroadcast(event, state)

          {:cont, state}
        else
          {:halt, state}
        end
      end)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        event = %{scope: _, type: _, payload: _},
        state
      ) do
    state = update_in(state.events, &(&1 ++ [event]))

    {:noreply, state}
  end

  defp do_rebroadcast(event, state) do
    topic = DelayedEvents.topic_for_event(event.scope, event.type, state.delay_ms)
    F1Bot.PubSub.broadcast(topic, event)

    [_event | rest_events] = state.events

    state
    |> Map.put(:events, rest_events)
  end

  defp ets_table_name(delay_ms), do: :"#{@ets_table_prefix}_#{delay_ms}"

  defp atom(x) when is_atom(x), do: x
  defp atom(x) when is_binary(x), do: String.to_atom(x)
end
