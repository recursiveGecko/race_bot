defmodule F1BotWeb.Component.VegaChart do
  use F1BotWeb, :component

  prop chart_id, :string, required: true
  prop class, :css_class, default: ""

  @impl true
  def render(assigns) do
    ~F"""
    <div class={@class} phx-update="ignore">
      <div id={@chart_id} class="w-full h-full" data-id={@chart_id} :hook>
      </div>
    </div>
    """
  end

  def push_init(socket, id, spec) do
    push_event(socket, "vega_chart:#{id}:init", %{spec: spec})
  end

  def push_update(socket, id, data) do
    push_event(socket, "vega_chart:#{id}:update", %{data: data})
  end
end
