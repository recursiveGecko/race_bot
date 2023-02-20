defmodule F1BotWeb.Component.DriverSummary do
  use F1BotWeb, :live_component
  alias F1BotWeb.Component

  prop delay_ms, :integer, required: true
  prop driver_info, :map, required: true
  data driver_summary, :map
  data session_best_stats, :map

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_load_data()

    {:ok, socket}
  end

  def maybe_load_data(socket = %{assigns: %{initial_load_complete: true}}) do
    socket
  end

  def maybe_load_data(socket) do
    delay_ms = socket.assigns.delay_ms
    driver_no = socket.assigns.driver_info.driver_number

    delayed_payload = fetch_delayed_event_payload("driver:#{driver_no}", :summary, delay_ms, nil)

    driver_summary =
      case delayed_payload[:driver_summary] do
        nil ->
          F1Bot.F1Session.DriverDataRepo.DriverData.Summary.empty_summary()

        value ->
          value
      end

    session_best_stats =
      case delayed_payload[:session_best_stats] do
        nil ->
          F1Bot.F1Session.DriverDataRepo.BestStats.new()
          |> Map.from_struct()

        value ->
          value
      end

    socket
    |> assign(:initial_load_complete, true)
    |> assign(:driver_summary, driver_summary)
    |> assign(:session_best_stats, session_best_stats)
  end

  def handle_summary_event(_event = %{type: :summary, payload: payload}) do
    %{
      driver_number: driver_number,
      driver_summary: driver_summary,
      session_best_stats: session_best_stats
    } = payload

    send_update(__MODULE__,
      id: driver_number,
      driver_summary: driver_summary,
      session_best_stats: session_best_stats
    )
  end

  def render(assigns) do
    ~F"""
    <div class="px-1 pt-1.5 pb-0.5 bg-slate-100 border border-slate-200 h-min drop-shadow rounded-lg">
      <div class="flex">
        <div
          class="bg-white shrink-0 hidden xs:block xs:w-12 xs:h-12 sm:w-14 sm:h-14 overflow-hidden rounded-full drop-shadow-md"
          style={"background-color: #" <> @driver_info.team_color}
        >
          <img
            class="max-w-none object-fill xs:w-16 xs:h-16 xs:object-[-3px_-2px] sm:w-20 sm:h-20 sm:object-[-5px_-3px]"
            alt={@driver_info.driver_abbr}
            src={@driver_info.picture_url}
          />
        </div>

        <div class="ml-2 mr-auto flex flex-col min-w-0">
          <span class="text-md text-ellipsis overflow-hidden">{"#{@driver_info.first_name} #{@driver_info.last_name}"}</span>
          <span class="text-sm text-gray-800 text-ellipsis overflow-hidden">{@driver_info.team_name}</span>
        </div>

        <div class="ml-2 grid grid-cols-[repeat(2,max-content)] gap-y-0.5 gap-x-3 text-sm">
          <div class="order-1">
            <span class="">Personal Best</span>
          </div>

          <div class="order-3 inline-grid grid-cols-[auto_max-content] gap-x-1" title="Fastest Lap">
            <!-- <span class="hidden sm:inline-block">Fastest Lap</span> -->
            <span class="___sm:hidden">FL</span>
            <Component.LapTimeField
              id={generate_field_id(@driver_info, :fastest_lap)}
              class="px-0.5 rounded border"
              stats={@driver_summary.stats}
              personal_best_stats={@driver_summary.stats}
              session_best_stats={@session_best_stats}
              kind={:fastest_lap}
            />
          </div>

          <div
            class="order-5 inline-grid grid-cols-[auto_max-content] gap-x-1 text-gray-500"
            title="Theoretical fastest lap achieved by adding up best sectors in this session"
          >
            <!-- <span class="hidden sm:inline-block">Theoretical FL</span> -->
            <span class="___sm:hidden">TFL</span>
            <Component.LapTimeField
              id={generate_field_id(@driver_info, :theoretical_fl)}
              class="px-0.5 rounded border"
              stats={@driver_summary.stats}
              personal_best_stats={@driver_summary.stats}
              session_best_stats={@session_best_stats}
              kind={:theoretical_fl}
            />
          </div>

          <span class="order-2 inline-grid grid-cols-[auto_max-content] gap-x-1" title="Fastest sector 1">
            <span class="justify-self-center">S1</span>
            <Component.LapTimeField
              id={generate_field_id(@driver_info, :fastest_sector_1)}
              class="px-0.5 rounded border"
              stats={@driver_summary.stats}
              personal_best_stats={@driver_summary.stats}
              session_best_stats={@session_best_stats}
              kind={{:fastest_sector, 1}}
            />
          </span>

          <span class="order-4 inline-grid grid-cols-[auto_max-content] gap-x-1" title="Fastest sector 2">
            <span class="justify-self-center">S2</span>
            <Component.LapTimeField
              id={generate_field_id(@driver_info, :fastest_sector_2)}
              class="px-0.5 rounded border"
              stats={@driver_summary.stats}
              personal_best_stats={@driver_summary.stats}
              session_best_stats={@session_best_stats}
              kind={{:fastest_sector, 2}}
            />
          </span>

          <span class="order-6 inline-grid grid-cols-[auto_max-content] gap-x-1" title="Fastest sector 3">
            <span class="justify-self-center">S3</span>
            <Component.LapTimeField
              id={generate_field_id(@driver_info, :fastest_sector_3)}
              class="px-0.5 rounded border"
              stats={@driver_summary.stats}
              personal_best_stats={@driver_summary.stats}
              session_best_stats={@session_best_stats}
              kind={{:fastest_sector, 3}}
            />
          </span>
        </div>
      </div>

      <p class="text-left text-sm mb-1 text-gray-500">Stint information</p>

      {#for stint <- @driver_summary.stints}
        <div class="mt-1 p-0.5 bg-white drop-shadow rounded-lg">
          <div class="flex flex-wrap items-center">
            <span class="mr-auto pl-0.5 pr-2">
              <Component.TyreSymbol
                class="h-6 inline-block"
                tyre_age={stint.tyre_age}
                compound={stint.compound}
              />
            </span>

            <span
              class="pr-2 sm:basis-auto text-sm text-gray-500"
              title="Stint start time (UTC)"
              :if={stint.start_time != nil}
            >
              {Timex.format!(stint.start_time, "{h24}:{m}")} UTC
            </span>
            <span class="pr-2 sm:basis-auto text-sm text-gray-500" title="Stint start/end (lap numbers)">
              Laps: {stint.lap_start}-{stint.lap_end}
            </span>
            <span
              class="pr-2 sm:basis-auto text-sm text-gray-500"
              title="Number of laps included in statistics (excl. outlaps, inlaps, VSC, SC)"
            >
              Timed laps: {stint.timed_laps}
            </span>
          </div>

          <div class="mt-0.5 grid grid-cols-[minmax(max-content,1.3fr)_repeat(3,1fr)] sm:grid-cols-4 gap-0.5">
            <div class="contents">
              <span class="text-sm" title="Fastest lap">
                <span class="block sm:hidden">&nbsp;</span>
                <span class="px-1 inline-block w-7">FL</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :fastest_lap)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={:fastest_lap}
                />
              </span>
              <span class="text-sm" title="Fastest sector 1">
                <span class="px-1 block sm:inline-block">S1</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :fastest_sector_1)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={{:fastest_sector, 1}}
                />
              </span>
              <span class="text-sm" title="Fastest sector 2">
                <span class="px-1 block sm:inline-block">S2</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :fastest_sector_2)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={{:fastest_sector, 2}}
                />
              </span>
              <span class="text-sm" title="Fastest sector 3">
                <span class="px-1 block sm:inline-block">S3</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :fastest_sector_3)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={{:fastest_sector, 3}}
                />
              </span>
            </div>

            <div class="contents text-gray-500">
              <span class="text-sm" title="Average lap">
                <span class="px-1 w-7 inline-block">Avg.</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :average_lap)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={:average_lap}
                />
              </span>
              <span class="text-sm" title="Average sector 1">
                <span class="px-1 hidden sm:inline-block">S1</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :average_sector_1)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={{:average_sector, 1}}
                />
              </span>
              <span class="text-sm" title="Average sector 2">
                <span class="px-1 hidden sm:inline-block">S2</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :average_sector_2)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={{:average_sector, 2}}
                />
              </span>
              <span class="text-sm" title="Average sector 3">
                <span class="px-1 hidden sm:inline-block">S3</span>
                <Component.LapTimeField
                  id={generate_field_id(@driver_info, stint, :average_sector_3)}
                  class="px-0.5 rounded border"
                  stats={stint.stats}
                  personal_best_stats={@driver_summary.stats}
                  session_best_stats={@session_best_stats}
                  kind={{:average_sector, 3}}
                />
              </span>
            </div>
          </div>
        </div>
      {/for}
    </div>
    """
  end

  def generate_field_id(driver_info, stint, kind) do
    generate_field_id(driver_info, "#{stint.number}-#{kind}")
  end

  def generate_field_id(driver_info, kind) do
    "ltf-#{driver_info.driver_number}-#{kind}"
  end
end
