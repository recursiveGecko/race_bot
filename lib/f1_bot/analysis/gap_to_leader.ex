defmodule F1Bot.Analysis.GapToLeader do
  @moduledoc """
  Calculates per-lap gap to the leader for creating visualizations
  """
  import F1Bot.Analysis.Common

  alias F1Bot.F1Session
  alias F1Bot.F1Session.DriverDataRepo.Lap

  def calculate(session = %F1Session{}) do
    from_lap = 1
    to_lap = session.lap_counter.current

    with true <- to_lap != nil,
         {:ok, driver_data} <- all_driver_data(session) do
      data =
        for lap <- from_lap..to_lap do
          calculate_for_lap(driver_data, lap)
        end

      {:ok, data}
    end
  end

  defp calculate_for_lap(all_driver_data, lap_no) do
    driver_numbers = Map.keys(all_driver_data)

    # Find lap timestamps for all drivers
    all_driver_timestamps =
      for driver_no <- driver_numbers do
        ts =
          case timestamp_for_driver_lap(all_driver_data, driver_no, lap_no) do
            nil -> nil
            ts -> DateTime.to_unix(ts, :millisecond)
          end

        {driver_no, ts}
      end

    # Find the driver who completed the lap first
    first_ts =
      all_driver_timestamps
      |> Enum.filter(fn {_, ts} -> ts != nil end)
      |> Enum.sort_by(fn {_, ts} -> ts end, :asc)
      |> List.first()
      |> case do
        nil -> nil
        {_, ts} -> ts
      end

    # Calculate gaps for all drivers
    gap_per_driver =
      for {driver_no, ts} <- all_driver_timestamps, into: %{} do
        delta_seconds =
          if first_ts == nil or ts == nil do
            nil
          else
            (ts - first_ts) / 1000
          end

        {driver_no, delta_seconds}
      end

    %{
      lap_number: lap_no,
      gap_per_driver: gap_per_driver
    }
  end

  defp timestamp_for_driver_lap(all_driver_data, driver_no, lap_no) do
    case fetch_driver_lap(all_driver_data, driver_no, lap_no) do
      {:ok, %Lap{timestamp: ts}} when ts != nil -> ts
      _ -> nil
    end
  end
end
