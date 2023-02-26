defmodule F1Bot.F1Session.EventGenerator.StateSync do
  alias F1Bot.F1Session
  alias F1Bot.F1Session.EventGenerator.{Driver, Charts}

  def state_sync_events(session = %F1Session{}) do
    driver_numbers = 1..99

    clock_events =
      if session.clock do
        [F1Session.Clock.to_event(session.clock)]
      else
        []
      end

    [
      clock_events,
      Charts.chart_init_events(session),
      F1Session.DriverCache.to_event(session.driver_cache),
      F1Session.SessionInfo.to_event(session.session_info),
      F1Session.LapCounter.to_event(session.lap_counter),
      F1Session.TrackStatusHistory.to_chart_events(session.track_status_history),
      Enum.map(driver_numbers, &Driver.summary_events(session, &1)),
      Enum.map(driver_numbers, &Driver.lap_time_chart_events(session, &1))
    ]
    |> List.flatten()
  end
end
