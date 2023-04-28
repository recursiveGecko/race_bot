defmodule F1Bot.F1Session.DriverDataRepo do
  @moduledoc """
  Coordinates processing, generates events and holds data (`F1Bot.F1Session.DriverDataRepo.DriverData`)
  belonging to each driver (e.g. laps, top speeds, car telemetry, car position), as well as the overall
  session statistics, such as the overall fastest lap and top speed.
  """
  use TypedStruct

  alias F1Bot.F1Session.LiveTimingHandlers.TimingData
  alias F1Bot.F1Session.DriverDataRepo
  alias F1Bot.F1Session.DriverDataRepo.{DriverData, BestStats, Events, Summary, Transcript}

  typedstruct do
    @typedoc "Repository for all car, lap time, and stint-related data"

    field(:drivers, map(), default: %{})
    field(:best_stats, DriverDataRepo.BestStats.t(), default: DriverDataRepo.BestStats.new())
    # a list of {timestamp_ms, time_ms}
    field(:all_lap_times, [{integer(), integer()}], default: [])
  end

  def new do
    %__MODULE__{}
  end

  def fetch(repo, driver_number) do
    case Map.fetch(repo.drivers, driver_number) do
      {:ok, val} -> {:ok, val}
      :error -> {:error, :driver_not_found}
    end
  end

  def driver_summary(
        repo = %__MODULE__{},
        driver_number,
        track_status_history
      )
      when is_integer(driver_number) do
    case fetch(repo, driver_number) do
      {:ok, data} ->
        summary = Summary.generate(data, track_status_history, repo.best_stats)
        {:ok, summary}

      {:error, error} ->
        {:error, error}
    end
  end

  def session_best_stats(repo) do
    repo.best_stats
  end

  def push_timing_data(repo, timing_data = %TimingData{}) do
    driver_data =
      repo
      |> fetch_or_create_driver_from_repo(timing_data.driver_number)

    driver_data =
      driver_data
      |> DriverData.push_timing_data(timing_data, repo.all_lap_times)

    pb_stats = DriverData.personal_best_stats(driver_data)

    # Store received lap time in a cache of all lap times for outlier detection
    repo =
      if timing_data.lap_time do
        Map.update(repo, :all_lap_times, [], fn all_lap_times ->
          time_ms = Timex.Duration.to_milliseconds(timing_data.lap_time)
          ts_ms = DateTime.to_unix(timing_data.timestamp, :millisecond)
          [{ts_ms, time_ms} | all_lap_times]
        end)
      else
        repo
      end

    {best_stats, events} = BestStats.push_personal_best_stats(repo.best_stats, pb_stats)

    repo =
      repo
      |> update_driver(driver_data)
      |> Map.put(:best_stats, best_stats)

    {repo, events}
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

  def process_transcript(repo, transcript = %Transcript{}) do
    {driver, events} =
      repo
      |> fetch_or_create_driver_from_repo(transcript.driver_number)
      |> DriverData.process_transcript(transcript)

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
