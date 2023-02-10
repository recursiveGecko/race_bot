defmodule F1Bot.F1Session.DriverDataRepo do
  @moduledoc """
  Coordinates processing, generates events and holds data (`F1Bot.F1Session.DriverDataRepo.DriverData`)
  belonging to each driver (e.g. laps, top speeds, car telemetry, car position), as well as the overall
  session statistics, such as the overall fastest lap and top speed.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo
  alias F1Bot.F1Session.DriverDataRepo.{DriverData, BestStats, Events}

  typedstruct do
    @typedoc "Repository for all car, lap time, and stint-related data"

    field(:drivers, map(), default: %{})
    field(:best_stats, DriverDataRepo.BestStats.t(), default: DriverDataRepo.BestStats.new())
  end

  def new do
    %__MODULE__{}
  end

  def info(repo, driver_number) do
    repo
    |> fetch_or_create_driver_from_repo(driver_number)
  end

  def driver_summary(repo, driver_number, track_status_history) when is_integer(driver_number) do
    data =
      repo
      |> info(driver_number)
      |> DriverData.Summary.generate(track_status_history)

    {:ok, data}
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
      {:ok, {driver_data, result}} ->
        {repo, events} = handle_push_lap_time_result(repo, driver_data, result, lap_time)
        {:ok, {repo, events}}

      {:error, error} ->
        {:error, error}
    end
  end

  def push_sector_time(repo, driver_number, sector, sector_time, timestamp) do
    driver =
      repo
      |> fetch_or_create_driver_from_repo(driver_number)
      |> DriverData.push_sector_time(sector, sector_time, timestamp)

    best_stats = repo.best_stats

    {best_stats, is_fastest_sector_overall, delta} =
      BestStats.push_sector_time(best_stats, sector, sector_time)

    events =
      if is_fastest_sector_overall do
        event =
          Events.make_agg_fastest_sector_event(
            driver.number,
            :overall,
            sector,
            sector_time,
            delta
          )

        [event]
      else
        []
      end

    repo = %{repo | best_stats: best_stats}
    repo = update_driver(repo, driver)
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

  defp handle_push_lap_time_result(repo, driver_data, result, lap_time) do
    driver_no = driver_data.number
    best_stats = repo.best_stats

    {best_stats, is_fastest_lap_overall, best_lap_delta} =
      BestStats.push_lap_time(best_stats, lap_time)

    {best_stats, is_top_speed_overall, best_speed_delta} =
      BestStats.push_top_speed(best_stats, result.lap_top_speed)

    lap_time_events =
      cond do
        is_fastest_lap_overall ->
          delta = best_lap_delta
          event = Events.make_agg_fastest_lap_event(driver_no, :overall, lap_time, delta)

          [event]

        result.is_fastest_lap ->
          delta = result.lap_delta
          event = Events.make_agg_fastest_lap_event(driver_no, :personal, lap_time, delta)

          [event]

        true ->
          []
      end

    top_speed_events =
      cond do
        is_top_speed_overall ->
          delta = best_speed_delta

          event =
            Events.make_agg_top_speed_event(driver_no, :overall, result.lap_top_speed, delta)

          [event]

        result.is_top_speed ->
          delta = result.speed_delta

          event =
            Events.make_agg_top_speed_event(driver_no, :personal, result.lap_top_speed, delta)

          [event]

        true ->
          []
      end

    events = lap_time_events ++ top_speed_events

    repo = %{repo | best_stats: best_stats}
    repo = update_driver(repo, driver_data)
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
