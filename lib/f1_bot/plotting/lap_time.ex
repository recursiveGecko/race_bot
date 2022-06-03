defmodule F1Bot.Plotting.LapTime do
  @moduledoc ""
  alias F1Bot.Plotting

  def plot(driver_numbers, options \\ []) do
    driver_data =
      driver_numbers
      |> collect_driver_data()

    options = Keyword.put_new(options, :x_axis, :lap)

    max_lap_time = find_max_lap_time(driver_data)

    {driver_list, datasets} =
      driver_data
      |> driver_data_to_dataset(max_lap_time, options)
      |> Enum.unzip()

    if Plotting.verify_datasets_nonempty(datasets) == :ok do
      file_path = Plotting.create_temp_file_path("png")

      gnuplot_options = create_plot_options(file_path, driver_list, options)

      Plotting.do_gnuplot(file_path, gnuplot_options, datasets)
    else
      {:error, :dataset_empty}
    end
  end

  defp find_max_lap_time(driver_data) do
    lap_times =
      driver_data
      |> Enum.map(fn {_, data} -> data.laps.data end)
      |> List.flatten()
      |> Enum.map(fn lap -> lap.time end)
      |> Enum.filter(fn time -> time != nil end)
      |> Enum.map(fn time -> Timex.Duration.to_milliseconds(time) end)
      |> Enum.sort(:asc)

    lap_count = length(lap_times)

    if lap_count == 0 do
      Timex.Duration.from_milliseconds(0)
    else
      bottom_10_percent = (lap_count * 0.1) |> floor()
      mean_lap = Enum.at(lap_times, bottom_10_percent)
      max_normal_lap = 1.06 * mean_lap

      max_normal_lap
      |> round()
      |> Timex.Duration.from_milliseconds()
    end
  end

  defp create_plot_options(
         file_path,
         driver_list,
         options
       ) do
    x_axis = Keyword.fetch!(options, :x_axis)

    plot_defs =
      for driver <- driver_list do
        # using_clause = '1:2'
        using_clause = '1:($2 != NaN  ? timecolumn(2, "%M:%S") : NaN)'

        case Keyword.get(options, :style, :lines) do
          :points ->
            [
              "-",
              :using,
              using_clause,
              :title,
              driver,
              :with,
              :points,
              :pointsize,
              1.5,
              :linewidth,
              2
            ]

          _ ->
            [
              "-",
              :using,
              using_clause,
              :title,
              driver,
              :with,
              :linespoints,
              :pointsize,
              1,
              # :pointtype,
              # 7,
              :linewidth,
              1.5
            ]
        end
      end

    title = get_graph_title()

    x_axis_opts =
      case x_axis do
        :lap ->
          [
            [:set, :xlabel, "Lap"],
            [:set, :xtics, 2],
            [:set, :mxtics, 2]
          ]

        :timestamp ->
          [
            [:set, :xlabel, "Session Time (UTC)"],
            [:set, :xdata, :time],
            [:set, :timefmt, "%H:%M:%S"]
          ]
      end

    x_axis_opts ++
      [
        # [:set, :terminal, :qt, :size, '1500,1000'],
        [:set, :terminal, :pngcairo, :size, '1500,1000'],
        [:set, :output, file_path],
        [:set, :title, title],
        [:set, :label, "BETA - May contain inaccuracies", :at, 'screen 0.8, screen 0.97'],
        [:show, :label],
        [:set, :linetype, '100', :linewidth, 0.5, :linecolor, :rgb, "black", :dashtype, 3],
        [:set, :linetype, '101', :linewidth, 0.1, :linecolor, :rgb, "black", :dashtype, 1],
        [:set, :style, :line, '100', :linetype, '100'],
        [:set, :style, :line, '101', :linetype, '101'],
        [:set, :grid, :xtics, :mxtics, :ytics, :mytics, 'ls 101, ls 100'],
        [:set, :key, :right, :top],
        [:set, :datafile, :missing, "?"],
        [:set, :ydata, :time],
        [:set, :ytics, 1],
        [:set, :mytics, 4],
        [:set, :ytics, :format, "%M:%.3S"],
        [:set, :ylabel, "Lap Time"],
        Gnuplot.plots(plot_defs)
      ]
  end

  defp collect_driver_data(driver_numbers) do
    driver_numbers
    |> Enum.map(&F1Bot.driver_session_data/1)
    |> Enum.filter(fn {x, _} -> x == :ok end)
    |> Enum.map(fn {_, data} -> data end)
    |> Enum.map(fn data = %{number: number} ->
      driver = get_driver_short_name(number)
      {driver, data}
    end)
  end

  defp get_driver_short_name(driver_number) do
    case F1Bot.driver_info_by_number(driver_number) do
      {:ok, info} -> info.driver_abbr
      _ -> "Car #{driver_number}"
    end
  end

  defp get_graph_title() do
    case F1Bot.session_info() do
      {:ok, info} -> "Lap Times at #{info.gp_name} (#{info.type})"
      _ -> "Lap Times"
    end
  end

  defp driver_data_to_dataset(drivers_data, max_lap_time, options) do
    x_axis = Keyword.fetch!(options, :x_axis)

    for {name, data} <- drivers_data do
      lap_data =
        for lap <- data.laps.data,
            lap.number != nil,
            lap.time != nil do
          lap_time = F1Bot.DataTransform.Format.format_lap_time(lap.time)

          longer_than_max = Timex.Duration.diff(max_lap_time, lap.time, :milliseconds) < 0

          x_value =
            case x_axis do
              :lap ->
                lap.number

              :timestamp ->
                {:ok, ts} = Timex.format(lap.timestamp, "{h24}:{m}:{s}")
                ts

              _ ->
                lap.number
            end

          if longer_than_max do
            # Change this to "?" if lines should NOT be broken up (or missing if there are no consecutive points)
            # Change this to "NaN" if lines should be broken up
            [x_value, "?"]
          else
            [x_value, lap_time]
          end
        end

      {name, lap_data}
    end
  end
end
