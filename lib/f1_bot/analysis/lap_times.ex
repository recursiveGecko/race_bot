defmodule F1Bot.Analysis.LapTimes do
  @moduledoc """
  Collects lap times for creating visualizations
  """
  import F1Bot.Analysis.Common

  alias F1Bot.F1Session
  alias F1Bot.F1Session.DriverDataRepo.{Lap, Laps}

  @doc """
  Compile a list of lap times for a given driver
  """
  def calculate(session = %F1Session{}, driver_number) do
    from_lap = 1

    to_lap =
      case session.lap_counter.current do
        nil -> 9999
        current -> current
      end

    neutralized_periods = neutralized_periods(session)

    # TODO: Optimise this, it's hard to cache results such as 'is_neutralized?'
    # because the underlying data is not always consistent with the API occasionally
    # providing garbage stint data and then correcting it later

    with {:ok, %Laps{data: laps}} <- fetch_driver_laps(session, driver_number),
         {:ok, stints} <- fetch_driver_stints(session, driver_number) do
      data =
        for lap = %Lap{} <- laps,
            lap.number != nil and lap.number <= to_lap and lap.number >= from_lap,
            not Lap.is_inlap?(lap, stints),
            not Lap.is_outlap?(lap, stints),
            not Lap.is_outlap_after_red_flag?(lap),
            not Lap.is_neutralized?(lap, neutralized_periods) do
          lap_to_chart_point(lap)
        end

      {:ok, data}
    end
  end

  def lap_to_chart_point(lap = %Lap{}) do
    lap
    |> point()
    |> serialize_point_values()
  end

  defp point(lap) do
    %{
      lap: lap.number,
      t: lap.time,
      ts: lap.timestamp
    }
  end

  defp serialize_point_values(point) do
    point
    |> update_in([:ts], fn
      nil -> nil
      ts -> DateTime.to_unix(ts, :millisecond)
    end)
    |> update_in([:t], fn
      nil -> nil
      time -> Timex.Duration.to_milliseconds(time, truncate: true)
    end)
  end
end
