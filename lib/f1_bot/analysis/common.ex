defmodule F1Bot.Analysis.Common do
  @moduledoc """
  Common functions for analysis
  """

  alias F1Bot.F1Session
  alias F1Bot.F1Session.TrackStatusHistory
  alias F1Bot.F1Session.DriverDataRepo.{DriverData, Laps}

  def all_driver_data(session = %F1Session{}) do
    case F1Session.driver_list(session) do
      {:ok, driver_list} ->
        data =
          driver_list
          |> Enum.map(& &1.driver_number)
          |> Enum.map(&{&1, F1Session.driver_session_data(session, &1)})
          |> Enum.into(%{})

        {:ok, data}
    end
  end

  def fetch_driver_all_laps(all_driver_data, driver_no) do
    case all_driver_data[driver_no] do
      nil -> {:error, :not_found}
      %DriverData{laps: laps} -> {:ok, laps}
    end
  end

  def fetch_driver_stints(all_driver_data, driver_no) do
    case all_driver_data[driver_no] do
      nil -> {:error, :not_found}
      %DriverData{stints: stints} -> {:ok, stints}
    end
  end

  def fetch_driver_lap(all_driver_data, driver_no, lap_no) do
    case all_driver_data[driver_no] do
      nil -> {:error, :not_found}
      %DriverData{laps: laps} -> Laps.fetch_by_number(laps, lap_no)
    end
  end

  def extend_vega_data_with_driver_info(data, session = %F1Session{}) when is_list(data) do
    with {:ok, all_info} <- all_driver_basic_info(session) do
      for datum <- data,
          info = all_info[datum.driver_number],
          info != nil do
        datum
        |> Map.put(:n, info.driver_abbr)
        |> Map.put(:c, "##{info.color}")
        |> Map.delete(:driver_number)
      end
    end
  end

  # TODO: Deduplicate this with extend_vega_data_with_driver_info
  def extend_vega_datum_with_driver_info(datum = %{}, session = %F1Session{}) do
    case F1Session.driver_info_by_number(session, datum.driver_number) do
      {:ok, info} ->
        datum =
          datum
          |> Map.put(:n, info.driver_abbr)
          |> Map.put(:c, "##{info.color}")
          |> Map.delete(:driver_number)

        {:ok, datum}

      {:error, error} ->
        {:error, error}
    end
  end

  def vega_track_data(session = %F1Session{}) do
    session
    |> neutralized_periods()
    |> Enum.map(fn interval ->
      %{
        lap_from: interval.lap_from,
        lap_to: interval.lap_to,
        ts_from: interval.starts_at,
        ts_to: interval.ends_at,
        status: TrackStatusHistory.humanize_status(interval.status),
        type:
          case interval.status do
            :red_flag -> "instant"
            _ -> "interval"
          end
      }
    end)
  end

  def neutralized_periods(session = %F1Session{}) do
    TrackStatusHistory.find_intervals_with_status(session.track_status_history, [
      :red_flag,
      :safety_car,
      :virtual_safety_car
    ])
  end

  def all_driver_basic_info(session = %F1Session{}) do
    case F1Session.driver_list(session) do
      {:ok, driver_list} ->
        data =
          for driver_info <- driver_list, into: %{} do
            info = %{
              driver_abbr: driver_info.driver_abbr,
              color: driver_info.team_color
            }

            {driver_info.driver_number, info}
          end

        {:ok, data}
    end
  end
end
