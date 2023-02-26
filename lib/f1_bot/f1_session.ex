defmodule F1Bot.F1Session do
  @moduledoc """
  Holds all state related to a given F1 session and coordinates data processing across modules in `F1Bot.F1Session` scope.

  All code in this scope is fully functional, without side effects. To communicate with other components
  that have side effects, such as posting to Twitter, it generates events that are processed by the caller, i.e.
  `F1Bot.F1Session.Server`.
  """
  use TypedStruct
  require Logger

  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event

  typedstruct do
    @typedoc "F1 Session State"

    field(:driver_data_repo, F1Session.DriverDataRepo.t(), default: F1Session.DriverDataRepo.new())

    field(:track_status_history, F1Session.TrackStatusHistory.t(),
      default: F1Session.TrackStatusHistory.new()
    )

    field(:race_control, F1Session.RaceControl.t(), default: F1Session.RaceControl.new())
    field(:driver_cache, F1Session.DriverCache.t(), default: F1Session.DriverCache.new())
    field(:session_info, F1Session.SessionInfo.t(), default: F1Session.SessionInfo.new())
    field(:session_status, atom())
    field(:clock, F1Session.Clock.t())
    field(:lap_counter, F1Session.LapCounter.t(), default: F1Session.LapCounter.new())
    field(:event_generator, F1Session.EventGenerator.t(), default: F1Session.EventGenerator.new())
  end

  def new(), do: %__MODULE__{}

  def driver_list(session) do
    F1Session.DriverCache.driver_list(session.driver_cache)
  end

  def driver_summary(session, driver_number) when is_integer(driver_number) do
    session.driver_data_repo
    |> F1Session.DriverDataRepo.driver_summary(driver_number, session.track_status_history)
  end

  def driver_info_by_number(session, driver_number) when is_integer(driver_number) do
    F1Session.DriverCache.get_driver_by_number(session.driver_cache, driver_number)
  end

  def driver_info_by_abbr(session, driver_abbr) do
    F1Session.DriverCache.get_driver_by_abbr(session.driver_cache, driver_abbr)
  end

  def driver_session_data(session, driver_number) when is_integer(driver_number) do
    F1Session.DriverDataRepo.info(session.driver_data_repo, driver_number)
  end

  def session_best_stats(session) do
    best_stats = F1Session.DriverDataRepo.session_best_stats(session.driver_data_repo)
    {:ok, best_stats}
  end

  def push_driver_list_update(session, drivers) do
    {driver_cache, events} = F1Session.DriverCache.process_updates(session.driver_cache, drivers)

    session = %{session | driver_cache: driver_cache}
    {session, events}
  end

  def push_sector_time(session, driver_number, sector, sector_time, timestamp)
      when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_sector_time(driver_number, sector, sector_time, timestamp)

    session = %{session | driver_data_repo: repo}

    events =
      events
      |> Event.attach_session_info(session)
      |> Event.attach_driver_info(session, [driver_number])

    driver_data_events =
      F1Session.EventGenerator.make_events_on_any_new_driver_data(session, driver_number)

    events = events ++ driver_data_events

    {session, events}
  end

  def push_lap_time(session, driver_number, lap_time, timestamp) when is_integer(driver_number) do
    push_result =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_lap_time(driver_number, lap_time, timestamp)

    {repo, events} =
      case push_result do
        {:ok, {repo, events}} ->
          {repo, events}

        {:error, _error} ->
          {session.driver_data_repo, []}
      end

    session = %{session | driver_data_repo: repo}

    events =
      events
      |> Event.attach_session_info(session)
      |> Event.attach_driver_info(session, [driver_number])

    driver_data_events =
      F1Session.EventGenerator.make_events_on_any_new_driver_data(session, driver_number)

    lap_time_chart_events =
      F1Session.EventGenerator.make_lap_time_chart_events(session, driver_number, nil)

    events = events ++ driver_data_events ++ lap_time_chart_events

    {session, events}
  end

  def push_lap_number(session, driver_number, lap_number, timestamp)
      when is_integer(driver_number) do
    driver_data_repo =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_lap_number(driver_number, lap_number, timestamp)

    session = %{session | driver_data_repo: driver_data_repo}

    {session, []}
  end

  def push_stint_data(session, driver_number, stint_data) when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_stint_data(driver_number, stint_data)

    session = %{session | driver_data_repo: repo}

    events =
      events
      |> Event.attach_session_info(session)
      |> Event.attach_driver_info(session, [driver_number])

    driver_data_events =
      F1Session.EventGenerator.make_events_on_any_new_driver_data(session, driver_number)

    events = events ++ driver_data_events

    {session, events}
  end

  def push_telemetry(session, driver_number, channels) when is_integer(driver_number) do
    repo =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_telemetry(driver_number, channels)

    %{session | driver_data_repo: repo}
  end

  def push_position(session, driver_number, position) when is_integer(driver_number) do
    repo =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_position(driver_number, position)

    %{session | driver_data_repo: repo}
  end

  def push_lap_counter_update(session, current_lap, total_laps, timestamp) do
    lap_counter =
      F1Session.LapCounter.update(session.lap_counter, current_lap, total_laps, timestamp)

    session = %{session | lap_counter: lap_counter}

    event = F1Session.LapCounter.to_event(lap_counter)

    {session, [event]}
  end

  def push_race_control_messages(session, messages) do
    {race_control, events} =
      session.race_control
      |> F1Session.RaceControl.push_messages(messages)

    events =
      events
      |> Event.attach_session_info(session)

    session = %{session | race_control: race_control}
    {session, events}
  end

  def push_session_info(session, session_info) do
    {session_info, events, should_reset} =
      session.session_info
      |> F1Session.SessionInfo.update(session_info)

    session = %{session | session_info: session_info}

    {session, events} =
      if should_reset do
        {session, reset_events} = reset_session(session)
        {session, events ++ reset_events}
      else
        {session, events}
      end

    {session, events}
  end

  def push_session_status(session, session_status) do
    old_status = session.session_status
    session = %{session | session_status: session_status}

    events =
      if old_status != session_status do
        event =
          F1Session.Common.Event.new("session_status:#{session_status}", %{
            gp_name: session.session_info.gp_name,
            session_status: session_status,
            session_type: session.session_info.type
          })

        [event]
      else
        []
      end

    events =
      events
      |> Event.attach_session_info(session)

    {session, events}
  end

  def push_track_status(session, track_status, timestamp) do
    lap_number = session.lap_counter.current

    {track_status, events} =
      session.track_status_history
      |> F1Session.TrackStatusHistory.push_track_status(track_status, lap_number, timestamp)

    session = %{session | track_status_history: track_status}
    {session, events}
  end

  def session_clock_from_local_time(session, local_time) do
    case session.clock do
      nil ->
        {:error, :clock_not_set}

      clock ->
        session_clock = F1Session.Clock.session_clock_from_local_time(clock, local_time)
        {:ok, session_clock}
    end
  end

  def update_clock(session, server_time, local_time, remaining, is_running) do
    clock = F1Session.Clock.new(server_time, local_time, remaining, is_running)
    session = %{session | clock: clock}
    events = [F1Session.Clock.to_event(clock)]

    {session, events}
  end

  def periodic_tick(session) do
    {event_generator, events} =
      F1Session.EventGenerator.make_periodic_events(session, session.event_generator)

    session = %{session | event_generator: event_generator}
    {session, events}
  end

  def reset_session(session) do
    # We reset the session then generate the summary events which contain an empty
    # summary because the DriverDataRepo had been reset.
    session = %{
      session
      | driver_data_repo: F1Session.DriverDataRepo.new(),
        track_status_history: F1Session.TrackStatusHistory.new(),
        race_control: F1Session.RaceControl.new(),
        lap_counter: F1Session.LapCounter.new(),
        clock: nil
    }

    reset_events = F1Session.EventGenerator.make_state_sync_events(session)

    {session, reset_events}
  end

  defdelegate make_state_sync_events(session), to: F1Session.EventGenerator
end
