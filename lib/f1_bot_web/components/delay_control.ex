defmodule F1BotWeb.Component.DelayControl do
  use F1BotWeb, :component

  prop pubsub_delay_ms, :integer, required: true
  prop increase_delay, :event, required: true
  prop decrease_delay, :event, required: true
  prop min_delay_ms, :integer, required: true
  prop max_delay_ms, :integer, required: true

  @impl true
  def render(assigns) do
    ~F"""
    <div class="flex flex-col items-baseline">
      <span class="font-semibold text-l">Delay</span>

      <div class="flex text-xl items-baseline">
        <button
          class="w-8 h-8 mr-2 bg-transparent inline hover:bg-blue-500 text-blue-700 font-semibold hover:text-white px-2 border border-blue-500 hover:border-transparent rounded"
          :on-click={@decrease_delay}
          disabled={@pubsub_delay_ms <= @min_delay_ms}
        >−</button>

        <span class="w-8 text-center">{(@pubsub_delay_ms / 1000) |> trunc()}s</span>

        <button
          class="w-8 h-8 ml-2 bg-transparent inline hover:bg-blue-500 text-blue-700 font-semibold hover:text-white px-2 border border-blue-500 hover:border-transparent rounded"
          :on-click={@increase_delay}
          disabled={@pubsub_delay_ms >= @max_delay_ms}
        >+</button>
      </div>
    </div>
    """
  end
end
