defmodule F1BotWeb.Component.LapAndClock do
  use F1BotWeb, :component

  alias F1Bot.DataTransform.Format

  prop is_race, :boolean, required: true
  prop lap_counter, :any, required: true
  prop session_clock, :any, required: true

  @impl true
  def render(assigns) do
    ~F"""
    <div class="flex items-baseline flex-col">
      {#if @is_race and @lap_counter != nil}
        <div class="text-2xl flex items-baseline mr-2 sm:mr-4 sm:mr-0">
          <span class="mr-2">Lap</span>
          <span>{@lap_counter.current || 0}</span>
          <span class="text-lg mx-1">/</span>
          <span class="text-lg" :if={@lap_counter.total != nil}>{@lap_counter.total}</span>
        </div>
      {/if}

      {#if @session_clock != nil}
        <span class={"sm:text-sm": @is_race, "text-2xl": not @is_race}>
          {Format.format_session_clock(@session_clock)}
        </span>
      {/if}
    </div>
    """
  end
end
