defmodule F1Bot.F1Session.EventGenerator do
  use TypedStruct
  alias F1Bot.F1Session.EventGenerator

  typedstruct do
    field(:event_deduplication, map(), default: %{})
  end

  def new do
    %__MODULE__{}
  end

  defdelegate make_driver_summary_events(session, driver_number),
    to: EventGenerator.Driver,
    as: :summary_events

  defdelegate make_periodic_events(session, event_generator),
    to: EventGenerator.Periodic,
    as: :periodic_events

  defdelegate make_session_reset_events(session),
    to: EventGenerator.SessionReset,
    as: :session_reset_events

  defdelegate make_state_sync_events(session),
    to: EventGenerator.StateSync,
    as: :state_sync_events

  def make_events_on_new_driver_data(session, driver_number) do
    [
      make_driver_summary_events(session, driver_number),
    ]
    |> List.flatten()
  end
end
