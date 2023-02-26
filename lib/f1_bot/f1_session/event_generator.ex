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

  defdelegate make_events_on_any_new_driver_data(session, driver_number),
    to: EventGenerator.Driver,
    as: :on_any_new_driver_data

  defdelegate make_lap_time_chart_events(session, driver_number, lap \\ nil),
    to: EventGenerator.Driver,
    as: :lap_time_chart_events

  defdelegate make_periodic_events(session, event_generator),
    to: EventGenerator.Periodic,
    as: :periodic_events

  defdelegate make_state_sync_events(session),
    to: EventGenerator.StateSync,
    as: :state_sync_events
end
