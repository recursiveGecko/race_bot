defmodule F1Bot.F1Session.EventGenerator.StateSync do
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.EventGenerator.Driver

  def state_sync_events(session = %F1Session{}) do
    driver_numbers =
      session
      |> F1Session.driver_list()
      |> elem(1)
      |> Enum.map(& &1.driver_number)

    [
      lap_time_chart_init_events(session),
      F1Session.DriverCache.to_event(session.driver_cache),
      F1Session.SessionInfo.to_event(session.session_info),
      F1Session.LapCounter.to_event(session.lap_counter),
      Enum.map(driver_numbers, &Driver.summary_events(session, &1)),
      F1Session.Clock.to_event(session.clock)
    ]
    |> List.flatten()
  end

  def lap_time_chart_init_events(session = %F1Session{}) do
    with {:ok, vega_spec} <- F1Bot.Analysis.LapTimes.plot_vegalite(session, 1..99) do
      [Event.new(:chart_init, :lap_times, vega_spec)]
    end
  end
end
