defmodule F1Bot.F1Session.EventGenerator.Driver do
  require Logger

  alias F1Bot.Analysis
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.EventGenerator

  def on_any_new_driver_data(session = %F1Session{}, driver_number) do
    cached_summaries = session.event_generator.event_deduplication[:driver_summary] || %{}

    # We generate a new summary for the driver that has new data and maybe
    # create events if the summary is different from before.
    {session, primary_driver_events} = summary_events(session, driver_number)

    # We also need to re-generate the summaries for any drivers that used
    # to have session best stats because they might have changed now.
    # Gather a list of those drivers.
    drivers_to_recheck =
      # If primary driver's summary hasn't changed, then nobody else's has
      if primary_driver_events == [] do
        []
      else
        cached_summaries
        |> Map.values()
        |> Stream.filter(fn summary -> summary.has_best_overall end)
        |> Enum.map(fn summary -> summary.driver_number end)
      end

    if drivers_to_recheck != [] do
      Logger.debug(
        "Driver #{driver_number} has new data, recalculating summaries for #{inspect(drivers_to_recheck, charlists: :as_lists)} because they had overall best stats"
      )
    end

    # Recalculate the summaries for those drivers and add accumulate
    # their events. Events are only generated if the summary is different
    # from before.
    {session, other_driver_events} =
      drivers_to_recheck
      |> Enum.reduce({session, []}, fn driver_number, {session, events} ->
        {session, new_events} = summary_events(session, driver_number)
        {session, new_events ++ events}
      end)

    events =
      [
        primary_driver_events,
        other_driver_events
      ]
      |> List.flatten()

    {session, events}
  end

  def summary_events(session = %F1Session{}, driver_number)
      when is_integer(driver_number) do
    with {:ok, summary} <- F1Session.driver_summary(session, driver_number),
         {session, _dup = false} <- check_set_deduplication(session, summary) do
      payload = %{
        driver_number: driver_number,
        driver_summary: summary
      }

      scope = "driver_summary:#{driver_number}"
      events = [Event.new(scope, payload)]
      {session, events}
    else
      {:error, _} ->
        {session, []}

      {session, _duplicated = true} ->
        {session, []}
    end
  end

  def lap_time_chart_events(session, driver_number)

  def lap_time_chart_events(session = %F1Session{}, driver_number)
      when is_integer(driver_number) do
    common_payload = %{
      dataset: "driver_data"
    }

    data_init_events =
      with {:ok, data} <- Analysis.LapTimes.calculate(session, driver_number),
           {:ok, driver_meta} <- fetch_driver_metadata(driver_number, session) do
        payload =
          common_payload
          |> Map.put(:data, data)
          |> Map.merge(driver_meta)

        e = Event.new("lap_time_chart_data_init:#{driver_number}", payload)
        [e]
      else
        _ ->
          []
      end

    data_init_events
  end

  defp fetch_driver_metadata(driver_number, session = %F1Session{}) do
    with {:ok, info} <- F1Session.driver_info_by_number(session, driver_number) do
      p = %{
        driver_name: info.last_name,
        driver_number: driver_number,
        driver_abbr: info.driver_abbr,
        team_color: info.team_color,
        chart_team_order: info.chart_team_order,
        chart_order: info.chart_order
      }

      {:ok, p}
    end
  end

  defp check_set_deduplication(
         session = %F1Session{},
         summary = %{driver_number: driver_number}
       ) do
    evt_gen = session.event_generator
    driver_summary_dedup = evt_gen.event_deduplication[:driver_summary] || %{}
    last_summary = driver_summary_dedup[driver_number]

    if last_summary == summary do
      {session, true}
    else
      driver_summary_dedup = Map.put(driver_summary_dedup, driver_number, summary)

      event_generator =
        EventGenerator.put_deduplication(
          evt_gen,
          :driver_summary,
          driver_summary_dedup
        )

      session = %{session | event_generator: event_generator}
      {session, false}
    end
  end
end
