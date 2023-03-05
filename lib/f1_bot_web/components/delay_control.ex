defmodule F1BotWeb.Component.DelayControl do
  use F1BotWeb, :live_component
  alias F1Bot.DelayedEvents

  prop pubsub_delay_ms, :integer, required: true
  data delay_step_ms, :integer, default: DelayedEvents.delay_step()
  data min_delay_ms, :integer, default: DelayedEvents.min_delay_ms()
  data max_delay_ms, :integer, default: DelayedEvents.max_delay_ms()
  data can_decrease, :boolean, default: false
  data can_increase, :boolean, default: false

  def update(new_assigns, socket) do
    socket = assign(socket, new_assigns)

    assigns = socket.assigns

    socket =
      socket
      |> assign(
        :can_increase,
        assigns.pubsub_delay_ms + assigns.delay_step_ms <= assigns.max_delay_ms
      )
      |> assign(
        :can_decrease,
        assigns.pubsub_delay_ms - assigns.delay_step_ms >= assigns.min_delay_ms
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <div class="flex flex-col items-baseline">
      <span class="font-semibold text-l">Delay</span>

      <div class="flex text-xl items-baseline">
        <button
          class={
            "transition-all w-8 h-8 mr-2 inline text-white font-semibold px-2 rounded",
            "bg-blue-500 dark:bg-blue-900 hover:bg-blue-700 dark:hover:bg-blue-600": @can_decrease,
            "bg-gray-500 dark:bg-gray-500": not @can_decrease
          }
          :on-click="delay-dec"
          disabled={not @can_decrease}
        >−</button>

        <span class="w-8 text-center">{(@pubsub_delay_ms / 1000) |> trunc()}s</span>

        <button
          class={
            "transition-all w-8 h-8 ml-2 inline text-white font-semibold px-2 rounded",
            "bg-blue-500 dark:bg-blue-900 hover:bg-blue-700 dark:hover:bg-blue-600": @can_increase,
            "bg-gray-500 dark:bg-gray-500": not @can_increase
          }
          :on-click="delay-inc"
          disabled={not @can_increase}
        >+</button>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delay-inc", _params, socket) do
    delay_ms = socket.assigns.pubsub_delay_ms + socket.assigns.delay_step_ms

    send(self(), {:delay_control_set, delay_ms})
    socket = Component.Utility.save_params(socket, %{delay_ms: delay_ms})

    {:noreply, socket}
  end

  @impl true
  def handle_event("delay-dec", _params, socket) do
    delay_ms = socket.assigns.pubsub_delay_ms - socket.assigns.delay_step_ms

    send(self(), {:delay_control_set, delay_ms})
    socket = Component.Utility.save_params(socket, %{delay_ms: delay_ms})

    {:noreply, socket}
  end
end
