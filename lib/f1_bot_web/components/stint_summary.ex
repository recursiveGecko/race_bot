defmodule F1BotWeb.Component.StintSummary do
  use F1BotWeb, :live_component
  alias F1BotWeb.Component

  prop stint, :map, required: true

  def render(assigns) do
    ~F"""
    <div id={@id} class="mt-1 p-0.5 bg-white dark:bg-[hsl(220,10%,15%)] drop-shadow rounded-lg">
      <div class="flex flex-wrap items-center text-sm text-gray-500 dark:text-gray-400">
        <span class="mr-auto pl-0.5 pr-2">
          <Component.TyreSymbol
            class="h-6 inline-block"
            tyre_age={@stint.tyre_age}
            compound={@stint.compound}
          />
        </span>

        <span class="pr-2" title="Stint start time (UTC)" :if={@stint.start_time != nil}>
          {Timex.format!(@stint.start_time, "{h24}:{m}")} UTC
        </span>
        <span class="pr-2 hidden xs:inline" title="Stint start/end (lap numbers)">
          Laps: {@stint.lap_start}-{@stint.lap_end}
        </span>
        <span class="pr-2" title="Number of laps included in statistics (excl. outlaps, inlaps, VSC, SC)">
          Timed laps: {@stint.timed_laps}
        </span>
      </div>

      <div class="mt-0.5 grid grid-cols-[repeat(4,minmax(min-content,max-content))] justify-between">
        <div class="contents">
          <span class="text-sm" title="Fastest lap">
            <span class="block xs:hidden">&nbsp;</span>
            <span class="px-1 inline-block w-7">FL</span>
            <Component.LapTimeField id={field_id(@id, :fastest_lap)} stat={@stint.stats.lap_time.fastest} />
          </span>
          <span class="text-sm" title="Fastest sector 1">
            <span class="px-1 block xs:inline-block text-gray-500 dark:text-gray-400">
              S1
            </span>
            <Component.LapTimeField
              id={field_id(@id, :fastest_sector_1)}
              stat={@stint.stats.s1_time.fastest}
            />
          </span>
          <span class="text-sm" title="Fastest sector 2">
            <span class="px-1 block xs:inline-block text-gray-500 dark:text-gray-400">
              S2
            </span>
            <Component.LapTimeField
              id={field_id(@id, :fastest_sector_2)}
              stat={@stint.stats.s2_time.fastest}
            />
          </span>
          <span class="text-sm" title="Fastest sector 3">
            <span class="px-1 block xs:inline-block text-gray-500 dark:text-gray-400">
              S3
            </span>
            <Component.LapTimeField
              id={field_id(@id, :fastest_sector_3)}
              stat={@stint.stats.s3_time.fastest}
            />
          </span>
        </div>

        <div class="contents text-gray-500 dark:text-gray-400">
          <span class="text-sm" title="Average lap">
            <span class="px-1 w-7 inline-block">Avg.</span>
            <Component.LapTimeField id={field_id(@id, :average_lap)} stat={@stint.stats.lap_time.average} />
          </span>
          <span class="text-sm" title="Average sector 1">
            <span class="px-1 hidden xs:inline-block">
              S1
            </span>
            <Component.LapTimeField
              id={field_id(@id, :average_sector_1)}
              stat={@stint.stats.s1_time.average}
            />
          </span>
          <span class="text-sm" title="Average sector 2">
            <span class="px-1 hidden xs:inline-block">
              S2
            </span>
            <Component.LapTimeField
              id={field_id(@id, :average_sector_2)}
              stat={@stint.stats.s2_time.average}
            />
          </span>
          <span class="text-sm" title="Average sector 3">
            <span class="px-1 hidden xs:inline-block">
              S3
            </span>
            <Component.LapTimeField
              id={field_id(@id, :average_sector_3)}
              stat={@stint.stats.s3_time.average}
            />
          </span>
        </div>
      </div>
    </div>
    """
  end

  def field_id(id, kind) do
    "ltf-#{id}-#{kind}"
  end
end
