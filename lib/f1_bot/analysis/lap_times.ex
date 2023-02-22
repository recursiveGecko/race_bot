defmodule F1Bot.Analysis.LapTimes do
  @moduledoc """
  Collects lap times for creating visualizations
  """
  import F1Bot.Analysis.Common

  alias F1Bot.DataTransform.Format
  alias F1Bot.F1Session
  alias F1Bot.F1Session.DriverDataRepo.{Lap, Laps}

  def calculate(session = %F1Session{}, driver_numbers) do
    from_lap = 1

    to_lap =
      case session.lap_counter.current do
        nil -> 9999
        current -> current
      end

    with {:ok, all_driver_data} <- all_driver_data(session) do
      neutralized_periods = neutralized_periods(session)

      all_driver_numbers = Map.keys(all_driver_data)

      # Find all relevant lap times for all drivers
      # TODO: Optimise this, it's hard to cache results such as 'is_neutralized?'
      # because the underlying data is not always consistent with the API occasionally
      # providing garbage stint data and then correcting it later
      data =
        for driver_no <- driver_numbers,
            driver_no in all_driver_numbers,
            {:ok, %Laps{data: laps}} = fetch_driver_all_laps(all_driver_data, driver_no),
            {:ok, stints} = fetch_driver_stints(all_driver_data, driver_no),
            lap = %Lap{} <- laps,
            lap.number != nil and lap.number <= to_lap and lap.number >= from_lap,
            not Lap.is_inlap?(lap, stints),
            not Lap.is_outlap?(lap, stints),
            not Lap.is_outlap_after_red_flag?(lap),
            # not false do
            not Lap.is_neutralized?(lap, neutralized_periods) do
          gen_datum(driver_no, lap)
        end

      {:ok, data}
    end
  end

  def lap_to_vegalite_datum(lap = %Lap{}, driver_number, session = %F1Session{}) do
    gen_datum(driver_number, lap)
    |> serialize_datum_values()
    |> extend_vega_datum_with_driver_info(session)
  end

  def generate_vegalite_dataset(session = %F1Session{}, driver_numbers) do
    with {:ok, data} <- calculate(session, driver_numbers) do
      dataset =
        data
        |> Enum.map(&serialize_datum_values/1)
        |> extend_vega_data_with_driver_info(session)

      {:ok, dataset}
    end
  end

  defp gen_datum(driver_number, lap) do
    %{
      driver_number: driver_number,
      lap: lap.number,
      t: lap.time,
      ts: lap.timestamp
    }
  end

  defp serialize_datum_values(datum) do
    datum
    |> update_in([:ts], fn
      nil -> nil
      ts -> DateTime.to_unix(ts, :second)
    end)
    |> update_in([:t], fn
      nil -> nil
      time -> Format.format_lap_time(time)
    end)
  end
end
