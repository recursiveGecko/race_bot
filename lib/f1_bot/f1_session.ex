defmodule F1Bot.F1Session do
  @moduledoc """
  Holds all state related to a given F1 session and coordinates data processing across modules in `F1Bot.F1Session` scope.

  All code in this scope is fully functional, without side effects. To communicate with other components
  that have side effects, such as posting to Twitter, it generates events that are processed by the caller, i.e.
  `F1Bot.F1Session.Server`.
  """
  use TypedStruct
  require Logger

  alias F1Bot.LightCopy.F1Bot.F1Session.DriverDataRepo
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.{DriverDataRepo, DriverCache, LapCounter}
  alias F1Bot.F1Session.DriverDataRepo.Transcript
  alias F1Bot.F1Session.LiveTimingHandlers.TimingData

  typedstruct do
    @typedoc "F1 Session State"

    field(:driver_data_repo, DriverDataRepo.t(), default: DriverDataRepo.new())

    field(:track_status_history, F1Session.TrackStatusHistory.t(),
      default: F1Session.TrackStatusHistory.new()
    )

    field(:race_control, F1Session.RaceControl.t(), default: F1Session.RaceControl.new())
    field(:driver_cache, DriverCache.t(), default: DriverCache.new())
    field(:session_info, F1Session.SessionInfo.t(), default: F1Session.SessionInfo.new())
    field(:session_status, atom())
    field(:clock, F1Session.Clock.t())
    field(:lap_counter, LapCounter.t(), default: LapCounter.new())
    field(:event_generator, F1Session.EventGenerator.t(), default: F1Session.EventGenerator.new())
  end

  def new(), do: %__MODULE__{}

  def driver_list(session) do
    DriverCache.driver_list(session.driver_cache)
  end

  def driver_summary(session, driver_number) when is_integer(driver_number) do
    session.driver_data_repo
    |> DriverDataRepo.driver_summary(driver_number, session.track_status_history)
  end

  def driver_info_by_number(session, driver_number) when is_integer(driver_number) do
    DriverCache.get_driver_by_number(session.driver_cache, driver_number)
  end

  def driver_info_by_abbr(session, driver_abbr) do
    DriverCache.get_driver_by_abbr(session.driver_cache, driver_abbr)
  end

  def driver_session_data(session, driver_number) when is_integer(driver_number) do
    DriverDataRepo.fetch(session.driver_data_repo, driver_number)
  end

  def session_best_stats(session) do
    best_stats = DriverDataRepo.session_best_stats(session.driver_data_repo)
    {:ok, best_stats}
  end

  def push_driver_list_update(session, drivers) do
    {driver_cache, events} = DriverCache.process_updates(session.driver_cache, drivers)

    session = %{session | driver_cache: driver_cache}
    {session, events}
  end

  def push_timing_data(
        session,
        timing_data = %TimingData{},
        skip_heavy_events \\ false
      ) do
    {repo, events} =
      DriverDataRepo.push_timing_data(
        session.driver_data_repo,
        timing_data
      )

    session = %{session | driver_data_repo: repo}

    events =
      events
      |> Event.attach_session_info(session)
      |> Event.attach_driver_info(session, [timing_data.driver_number])

    if !skip_heavy_events do
      {session, driver_data_events} =
        F1Session.EventGenerator.make_events_on_any_new_driver_data(
          session,
          timing_data.driver_number
        )

      events = events ++ driver_data_events
      {session, events}
    else
      {session, []}
    end
  end

  def push_stint_data(
        session,
        driver_number,
        stint_data,
        skip_heavy_events \\ false
      )
      when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> DriverDataRepo.push_stint_data(driver_number, stint_data)

    session = %{session | driver_data_repo: repo}

    events =
      events
      |> Event.attach_session_info(session)
      |> Event.attach_driver_info(session, [driver_number])

    if !skip_heavy_events do
      {session, driver_data_events} =
        F1Session.EventGenerator.make_events_on_any_new_driver_data(session, driver_number)

      events = events ++ driver_data_events
      {session, events}
    else
      {session, []}
    end
  end

  def push_telemetry(session, driver_number, channels) when is_integer(driver_number) do
    repo =
      session.driver_data_repo
      |> DriverDataRepo.push_telemetry(driver_number, channels)

    %{session | driver_data_repo: repo}
  end

  def push_position(session, driver_number, position) when is_integer(driver_number) do
    repo =
      session.driver_data_repo
      |> DriverDataRepo.push_position(driver_number, position)

    %{session | driver_data_repo: repo}
  end

  def process_transcript(session, transcript = %Transcript{}) do
    {repo, events} = DriverDataRepo.process_transcript(session.driver_data_repo, transcript)
    events = Event.attach_driver_info(events, session, [transcript.driver_number])

    session = %{session | driver_data_repo: repo}
    {session, events}
  end

  def push_lap_counter_update(session, current_lap, total_laps, timestamp) do
    lap_counter = LapCounter.update(session.lap_counter, current_lap, total_laps, timestamp)
    session = %{session | lap_counter: lap_counter}

    event = LapCounter.to_event(lap_counter)

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

  def push_session_info(session, session_info, local_time, ignore_reset) do
    {session_info, events, should_reset} =
      session.session_info
      |> F1Session.SessionInfo.update(session_info)

    session = %{session | session_info: session_info}

    {session, events, do_reset_session} =
      if should_reset and !ignore_reset do
        {session, reset_events} = reset_session(session, local_time)
        {session, events ++ reset_events, true}
      else
        {session, events, false}
      end

    {session, events, do_reset_session}
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
    events = [F1Session.Clock.to_event(clock, local_time)]

    {session, events}
  end

  def periodic_tick(session, local_time) do
    {event_generator, events} =
      F1Session.EventGenerator.make_periodic_events(session, session.event_generator, local_time)

    session = %{session | event_generator: event_generator}
    {session, events}
  end

  def reset_session(session, local_time) do
    # We reset the session then generate the summary events which contain an empty
    # summary because the DriverDataRepo had been reset.
    session = %{
      session
      | driver_data_repo: DriverDataRepo.new(),
        track_status_history: F1Session.TrackStatusHistory.new(),
        race_control: F1Session.RaceControl.new(),
        lap_counter: LapCounter.new(),
        clock: nil
    }

    {session, state_sync_events} =
      F1Session.EventGenerator.make_state_sync_events(session, local_time)

    {session, state_sync_events}
  end

  defdelegate make_state_sync_events(session, local_time), to: F1Session.EventGenerator
end
