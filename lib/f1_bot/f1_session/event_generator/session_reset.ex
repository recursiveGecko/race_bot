defmodule F1Bot.F1Session.EventGenerator.SessionReset do
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.EventGenerator.{Driver, Charts}

  def session_reset_events(session = %F1Session{}) do
    reset_event = Event.new(:session_info, :reset_session, nil)

    summary_events =
      1..99
      |> Enum.map(&Driver.summary_events(session, &1))
      |> List.flatten()

    chart_init_events = Charts.chart_init_events(session)

    [
      reset_event,
      summary_events,
      chart_init_events
    ]
    |> List.flatten()
  end
end
