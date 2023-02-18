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

  def initialize(socket, id, spec) do
    payload = %{spec: spec}
    push_event(socket, "vega_chart:#{id}:init", payload)
  end

  def insert_data(socket, id, dataset, data) do
    payload = %{dataset: dataset, op: "insert", data: data}
    push_event(socket, "vega_chart:#{id}:data", payload)
  end

  def replace_data(socket, id, dataset, data) do
    payload = %{dataset: dataset, op: "replace", data: data}
    push_event(socket, "vega_chart:#{id}:data", payload)
  end
end
