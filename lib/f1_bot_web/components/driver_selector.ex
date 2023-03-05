defmodule F1BotWeb.Component.DriverSelector do
  use F1BotWeb, :component

  prop driver_list, :list, required: true
  prop drivers_of_interest, :list, required: true
  prop toggle_driver, :event, required: true

  @impl true
  def render(assigns) do
    ~F"""
    <div class="grid gap-1 grid-cols-3 sm:grid-cols-none">
      {#for driver_info <- @driver_list}
        <button
          class={
            "px-1 rounded border-l-4 border-b-2 text-left drop-shadow",
            selected_classes(driver_info, @drivers_of_interest)
          }
          style={
            selected_styles(driver_info, @drivers_of_interest)
          }
          :on-click={@toggle_driver}
          :values={driver_number: driver_info.driver_number}
        >
          <span class="">{driver_info.last_name || driver_info.short_name}</span>
        </button>
      {/for}
    </div>
    """
  end

  defp selected_classes(driver_info, drivers_of_interest) do
    if driver_info.driver_number in drivers_of_interest do
      "bg-white dark:bg-[hsl(220,15%,20%)]"
    else
      "bg-slate-200 dark:bg-[hsl(220,15%,11%)]"
    end
  end

  defp selected_styles(driver_info, drivers_of_interest) do
    team_color = "##{driver_info.team_color}"
    if driver_info.driver_number in drivers_of_interest do
      "border-left-color: #{team_color}; border-bottom-color: #{team_color};"
    else
      "border-left-color: #{team_color}; border-bottom-color: transparent;"
    end
  end
end
