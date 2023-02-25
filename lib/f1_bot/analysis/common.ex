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
          |> Stream.map(& &1.driver_number)
          |> Stream.map(&{&1, F1Session.driver_session_data(session, &1)})
          |> Stream.filter(fn {status, _} -> status == :ok end)
          |> Stream.map(fn {_ok, data} -> data end)
          |> Enum.into(%{})

        {:ok, data}
    end
  end

  def fetch_driver_laps(session = %F1Session{}, driver_no) do
    case F1Session.driver_session_data(session, driver_no) do
      {:ok, %DriverData{laps: laps}} -> {:ok, laps}
      {:error, error} -> {:error, error}
    end
  end

  def fetch_driver_stints(session = %F1Session{}, driver_no) do
    case F1Session.driver_session_data(session, driver_no) do
      {:ok, %DriverData{stints: stints}} -> {:ok, stints}
      {:error, error} -> {:error, error}
    end
  end

  def fetch_driver_lap(all_driver_data, driver_no, lap_no) do
    case all_driver_data[driver_no] do
      nil -> {:error, :not_found}
      %DriverData{laps: laps} -> Laps.fetch_by_number(laps, lap_no)
    end
  end

  def neutralized_periods(session = %F1Session{}) do
    TrackStatusHistory.find_intervals_with_status(session.track_status_history, [
      :red_flag,
      :safety_car,
      :virtual_safety_car
    ])
  end
end
