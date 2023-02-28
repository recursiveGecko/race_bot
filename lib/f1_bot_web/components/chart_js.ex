defmodule F1BotWeb.Component.ChartJS do
  use F1BotWeb, :component
  alias Phoenix.LiveView

  prop chart_id, :string, required: true
  prop class, :css_class, default: ""

  @impl true
  def render(assigns) do
    ~F"""
    <div class={@class} phx-update="ignore">
      <canvas id={@chart_id} class="w-full h-full absolute" :hook>
        Your browser does not support HTML5 canvas to render this chart.
      </canvas>
    </div>
    """
  end

  def initialize(socket, id, chart_class) do
    payload = %{chart_class: chart_class}
    LiveView.push_event(socket, "chartjs:#{id}:init", payload)
  end

  def insert_data(socket, id, payload) do
    payload =
      payload
      |> Map.put(:op, "insert")

    LiveView.push_event(socket, "chartjs:#{id}:data", payload)
  end

  def replace_data(socket, id, payload) do
    payload =
      payload
      |> Map.put(:op, "replace")

    LiveView.push_event(socket, "chartjs:#{id}:data", payload)
  end
end
