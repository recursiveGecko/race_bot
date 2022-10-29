defmodule F1Bot.Analysis.LapTimes do
  @moduledoc """
  Collects lap times for creating visualizations
  """
  use Memoize
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

      # Find all lap times for all drivers
      data =
        for driver_no <- all_driver_numbers,
            driver_no in driver_numbers,
            {:ok, %Laps{data: laps}} = fetch_driver_all_laps(all_driver_data, driver_no),
            {:ok, stints} = fetch_driver_stints(all_driver_data, driver_no),
            lap = %Lap{} <- laps,
            lap.number != nil and lap.number <= to_lap and lap.number >= from_lap,
            not Lap.is_inlap?(lap, stints),
            not Lap.is_outlap?(lap, stints),
            not Lap.is_outlap_after_red_flag?(lap),
            not Lap.is_neutralized?(lap, neutralized_periods) do
          %{
            driver_number: driver_no,
            lap: lap.number,
            t: lap.time,
            ts: lap.timestamp
          }
        end

      {:ok, data}
    else
      false -> {:error, :missing_current_lap}
    end
  end

  def plot_vegalite(session = %F1Session{}, driver_numbers) do
    is_race = F1Session.SessionInfo.is_race?(session.session_info)

    spec_name =
      if is_race do
        "lap_times_race"
      else
        "lap_times_quali"
      end

    with {:ok, spec} <- load_spec(spec_name),
         {:ok, data} <- calculate(session, driver_numbers) do
      data =
        session
        |> extend_vega_data_with_driver_info(data)
        |> serialize_data_values()

      spec =
        spec
        |> put_in(["datasets", "driver_data"], data)
        # TODO: Add data
        |> put_in(["datasets", "track_data"], [])
        |> put_in(["params", Access.filter(&(&1["name"] == "current_lap")), "value"], 0)
        |> put_in(["title"], "Lap times")

      {:ok, spec}
    end
  end

  defp serialize_data_values(data) do
    for datum <- data do
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

  defp load_spec(file_name) do
    :f1_bot
    |> Application.app_dir("priv/vega/#{file_name}.json")
    |> File.read()
    |> case do
      {:ok, json} -> Jason.decode(json)
      {:error, reason} -> {:error, reason}
    end
  end
end
