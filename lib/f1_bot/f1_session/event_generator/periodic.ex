defmodule F1Bot.F1Session.EventGenerator.Periodic do
  alias F1Bot.F1Session.{Clock, EventGenerator}

  def periodic_events(session, event_generator) do
    {event_generator, clock_events} =
      maybe_generate_session_clock_events(event_generator, session.clock)

    {event_generator, clock_events}
  end

  defp maybe_generate_session_clock_events(event_generator = %EventGenerator{}, _clock = nil) do
    {event_generator, []}
  end

  defp maybe_generate_session_clock_events(event_generator = %EventGenerator{}, clock = %Clock{}) do
    with session_clock <- Clock.session_clock_from_local_time(clock, Timex.now()),
         last_session_clock <- event_generator.event_deduplication[:session_clock],
         true <- session_clock != last_session_clock do
      events = [Clock.to_event(clock)]

      event_generator =
        put_in(event_generator, [Access.key(:event_deduplication), :session_clock], session_clock)

      {event_generator, events}
    else
      _ -> {event_generator, []}
    end
  end
end
