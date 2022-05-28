defmodule F1Bot.F1Session.Impl do
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

    field(:race_control, F1Session.RaceControl.t(), default: F1Session.RaceControl.new())
    field(:driver_cache, F1Session.DriverCache.t(), default: F1Session.DriverCache.new())
    field(:session_info, F1Session.SessionInfo.t(), default: F1Session.SessionInfo.new())
    field(:session_status, atom())
  end

  def new(), do: %__MODULE__{}

  def driver_info_by_number(session, driver_number) when is_integer(driver_number) do
    F1Session.DriverCache.get_driver_by_number(session.driver_cache, driver_number)
  end

  def driver_info_by_abbr(session, driver_abbr) do
    F1Session.DriverCache.get_driver_by_abbr(session.driver_cache, driver_abbr)
  end

  def driver_session_data(session, driver_number) when is_integer(driver_number) do
    F1Session.DriverDataRepo.info(session.driver_data_repo, driver_number)
  end

  def push_driver_list_update(session, drivers) do
    driver_cache =
      Enum.reduce(drivers, session.driver_cache, fn driver, driver_cache ->
        F1Session.DriverCache.process_update(driver_cache, driver)
      end)

    %{session | driver_cache: driver_cache}
  end

  def push_lap_time(session, driver_number, lap_time, timestamp) when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_lap_time(driver_number, lap_time, timestamp)

    session = %{session | driver_data_repo: repo}
    {session, events}
  end

  def push_sector_time(session, driver_number, sector, sector_time, timestamp)
      when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_sector_time(driver_number, sector, sector_time, timestamp)

    session = %{session | driver_data_repo: repo}
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

    session = %{session | race_control: race_control}
    {session, events}
  end

  def push_session_info(session, session_info) do
    {session_info, should_reset} =
      session.session_info
      |> F1Session.SessionInfo.update(session_info)

    session = %{session | session_info: session_info}

    if should_reset do
      reset_session(session)
    else
      session
    end
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

    {session, events}
  end

  def push_stint_data(session, driver_number, stint_data) when is_integer(driver_number) do
    {repo, events} =
      session.driver_data_repo
      |> F1Session.DriverDataRepo.push_stint_data(driver_number, stint_data)

    session = %{session | driver_data_repo: repo}
    {session, events}
  end

  defp reset_session(session) do
    %__MODULE__{
      session
      | driver_data_repo: F1Session.DriverDataRepo.new(),
        race_control: F1Session.RaceControl.new()
    }
  end
end
