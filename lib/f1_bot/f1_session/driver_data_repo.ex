defmodule F1Bot.F1Session.DriverDataRepo do
  @moduledoc """
  Coordinates processing, generates events and holds data (`F1Bot.F1Session.DriverDataRepo.DriverData`)
  belonging to each driver (e.g. laps, top speeds, car telemetry, car position), as well as the overall
  session statistics, such as the overall fastest lap and top speed.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo
  alias F1Bot.F1Session.DriverDataRepo.{DriverData, BestStats, Events}

  alias F1Bot.F1Session.DriverDataRepo.DriverData.{
    EndOfLapResult,
    EndOfSectorResult
  }

  typedstruct do
    @typedoc "Repository for all car, lap time, and stint-related data"

    field(:drivers, map(), default: %{})
    field(:best_stats, DriverDataRepo.BestStats.t(), default: DriverDataRepo.BestStats.new())
  end

  def new do
    %__MODULE__{}
  end

  def info(repo, driver_number) do
    data =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)

    {:ok, data}
  end

  def driver_summary(repo, driver_number, track_status_history) when is_integer(driver_number) do
    summary =
      case info(repo, driver_number) do
        {:ok, data} -> DriverData.Summary.generate(data, track_status_history)
      end

    {:ok, summary}
  end

  def session_best_stats(repo) do
    repo.best_stats
  end

  def push_lap_time(repo, driver_number, lap_time, timestamp) do
    push_result =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)
      |> DriverData.push_lap_time(lap_time, timestamp)

    case push_result do
      {:ok, {driver_data, eol_result = %EndOfLapResult{}}} ->
        # Save updated DriverData
        repo = update_driver(repo, driver_data)

        # Determine if this lap had record pace or top speed, creates PB/overall best events
        {best_stats, events} = BestStats.push_end_of_lap_result(repo.best_stats, eol_result)
        repo = %{repo | best_stats: best_stats}

        {:ok, {repo, events}}

      {:error, error} ->
        {:error, error}
    end
  end

  def push_sector_time(repo, driver_number, sector, sector_time, timestamp) do
    {driver_data, eos_result = %EndOfSectorResult{}} =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)
      |> DriverData.push_sector_time(sector, sector_time, timestamp)

    {best_stats, events} = BestStats.push_end_of_sector_result(repo.best_stats, eos_result)

    repo = %{repo | best_stats: best_stats}
    repo = update_driver(repo, driver_data)
    {repo, events}
  end

  def push_lap_number(repo, driver_number, lap_number, timestamp) do
    driver =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)
      |> DriverData.push_lap_number(lap_number, timestamp)

    update_driver(repo, driver)
  end

  def push_telemetry(repo, driver_number, telemetry) do
    driver =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)
      |> DriverData.push_telemetry(telemetry)

    update_driver(repo, driver)
  end

  def push_position(repo, driver_number, position) do
    driver =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)
      |> DriverData.push_position(position)

    update_driver(repo, driver)
  end

  def push_stint_data(repo, driver_number, stint_data) do
    {driver, result} =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)
      |> DriverData.push_stint_data(stint_data)

    events = Events.make_tyre_change_events(driver, result)

    repo = update_driver(repo, driver)
    {repo, events}
  end

  defp fetch_or_create_driver_from_repo(_repo = %{drivers: drivers}, driver_number) do
    case Map.fetch(drivers, driver_number) do
      {:ok, val} -> val
      :error -> DriverData.new(driver_number)
    end
  end

  defp update_driver(repo, driver_struct) do
    %{repo | drivers: Map.put(repo.drivers, driver_struct.number, driver_struct)}
  end
end
