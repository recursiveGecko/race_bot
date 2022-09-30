defmodule F1Bot.F1Session do
  @moduledoc """
  Holds all state related to a given F1 session and coordinates data processing across modules in `F1Bot.F1Session` scope.

  All code in this scope is fully functional, without side effects. To communicate with other components
  that have side effects, such as posting to Twitter, it generates events that are processed by the caller, i.e.
  `F1Bot.F1Session.Server`.
  """
  use TypedStruct

  alias F1Bot.F1Session

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
    field(:event_deduplication, map(), default: %{})
  end

  def new(), do: %__MODULE__{}

  def driver_list(session) do
    F1Session.DriverCache.driver_list(session.driver_cache)
  end

  def driver_summary(session, driver_number) when is_integer(driver_number) do
    data =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.info(driver_number)
      |> F1Session.DriverDataRepo.DriverData.Summary.generate(session.track_status_history)

    {:ok, data}
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

    events = hydrate_events(session, events)

    summary_events =
      F1Session.EventGenerator.generate_driver_summary_events(session, driver_number)

    events = summary_events ++ events

    {session, events}
  end

  def push_sector_time(session, driver_number, sector, sector_time, timestamp)
      when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_sector_time(driver_number, sector, sector_time, timestamp)

    session = %{session | driver_data_repo: repo}

    events = hydrate_events(session, events)

    summary_events =
      F1Session.EventGenerator.generate_driver_summary_events(session, driver_number)

    events = summary_events ++ events

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

  def push_lap_number(session, driver_number, lap_number, timestamp)
      when is_integer(driver_number) do
    driver_data_repo =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_lap_number(driver_number, lap_number, timestamp)

    session_info =
      session.session_info
      |> F1Session.SessionInfo.push_lap_number(lap_number)

    %{session | driver_data_repo: driver_data_repo, session_info: session_info}
  end

  def push_race_control_messages(session, messages) do
    {race_control, events} =
      session.race_control
      |> F1Session.RaceControl.push_messages(messages)

    events = hydrate_events(session, events)

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
          F1Session.Common.Event.new(:session_status, session_status, %{
            gp_name: session.session_info.gp_name,
            session_type: session.session_info.type
          })

        [event]
      else
        []
      end

    events = hydrate_events(session, events)

    {session, events}
  end

  def push_stint_data(session, driver_number, stint_data) when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_stint_data(driver_number, stint_data)

    session = %{session | driver_data_repo: repo}

    events = hydrate_events(session, events)

    summary_events =
      F1Session.EventGenerator.generate_driver_summary_events(session, driver_number)

    events = summary_events ++ events

    {session, events}
  end

  def push_track_status(session, track_status, timestamp) do
    track_status =
      session.track_status_history
      |> F1Session.TrackStatusHistory.push_track_status(track_status, timestamp)

    session = %{session | track_status_history: track_status}
    {session, []}
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
    %{session | clock: clock}
  end

  def periodic_tick(session) do
    {session, events} =
      [
        &F1Session.EventGenerator.maybe_generate_session_clock_events/1
      ]
      |> Enum.reduce(
        {session, []},
        fn fun, {session, events} ->
          {new_session, new_events} = fun.(session)
          {new_session, events ++ new_events}
        end
      )

    {session, events}
  end

  def reset_session(session) do
    # We reset the session then generate the summary events ...
    # (which should contain an empty summary because the DriverDataRepo has been reset
    # and an empty DriverData container should be created on access)
    # ... for all drivers in the previous session (because we pass a list of drivers
    # from the previous session),
    {:ok, driver_list} = F1Session.DriverCache.driver_list(session.driver_cache)
    driver_numbers = Enum.map(driver_list, & &1.driver_number)

    session = %__MODULE__{
      session
      | driver_data_repo: F1Session.DriverDataRepo.new(),
        track_status_history: F1Session.TrackStatusHistory.new(),
        race_control: F1Session.RaceControl.new(),
        clock: nil
    }

    reset_events = F1Session.EventGenerator.generate_session_reset_events(session, driver_numbers)

    {session, reset_events}
  end

  defp hydrate_events(session, events) do
    for e <- events do
      %{
        e
        | session_status: session.session_status,
          session_info: session.session_info,
          driver_cache: session.driver_cache
      }
    end
  end
end
