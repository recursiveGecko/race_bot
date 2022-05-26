defmodule F1Bot.Plotting.Gap do
  @moduledoc ""
  alias F1Bot.Plotting

  def plot(driver_numbers, options \\ []) do
    driver_data =
      driver_numbers
      |> collect_driver_data()

    {driver_list, datasets} =
      driver_data
      |> driver_data_to_dataset()
      # |> IO.inspect()
      |> Enum.unzip()

    [zero_driver | _rest] = driver_list
    options = Keyword.put(options, :zero_driver, zero_driver)

    file_path = Plotting.create_temp_file_path("png")

    options = create_plot_options(file_path, driver_list, options)

    if Plotting.verify_datasets_nonempty(datasets) == :ok do
      Plotting.do_gnuplot(file_path, options, datasets)
    else
      {:error, :dataset_empty}
    end
  end

  defp create_plot_options(
         file_path,
         driver_list,
         options
       ) do
    plot_defs =
      for driver <- driver_list do
        case Keyword.get(options, :style, :lines) do
          :points ->
            [
              "-",
              :using,
              '1:2',
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
            ["-", :using, '1:2', :title, driver, :with, :lines, :linewidth, 1.5]
        end
      end

    title =
      Keyword.get(options, :zero_driver, "driver")
      |> get_graph_title()

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
      [:set, :xtics, 2],
      [:set, :mxtics, 2],
      [:set, :xlabel, "Lap"],
      # [:set, :ydata, :time],
      [:set, :mytics],
      # [:set, :ytics, '1'],
      [:set, :ylabel, "Gap (sec)"],
      [:set, :offsets, '0, 0, 1, 0.1'],
      Gnuplot.plots(plot_defs)
    ]
  end

  defp get_driver_short_name(driver_number) do
    case F1Bot.driver_info(driver_number) do
      {:ok, info} -> info.driver_abbr
      _ -> "Car #{driver_number}"
    end
  end

  defp get_graph_title(zero_driver) do
    case F1Bot.session_info() do
      {:ok, info} -> "Gap to #{zero_driver} at #{info.gp_name} (#{info.type})"
      _ -> "Gap to #{zero_driver}"
    end
  end

  defp collect_driver_data(driver_numbers) do
    driver_numbers
    |> Enum.map(&F1Bot.driver_stats/1)
    |> Enum.filter(fn {x, _} -> x == :ok end)
    |> Enum.map(fn {_, data} -> data end)
    |> Enum.map(fn data = %{number: number} ->
      driver = get_driver_short_name(number)
      {driver, data}
    end)
  end

  defp driver_data_to_dataset(drivers_data) do
    [{_first_driver_name, first_driver_data} | _rest] = drivers_data

    first_driver_data =
      first_driver_data
      |> extract_lap_data_from_driver()

    for {name, driver_data} <- drivers_data do
      driver_data =
        driver_data
        |> extract_lap_data_from_driver()

      gap_data = map_lap_data_to_relative_time(first_driver_data, driver_data)

      {name, gap_data}
    end
  end

  defp extract_lap_data_from_driver(%{laps: %{data: data}}) do
    Enum.map(data, fn l -> {l.number, l.timestamp} end)
    |> Enum.filter(fn {number, ts} -> number != nil and ts != nil end)
    |> Enum.sort_by(fn {number, _ts} -> number end, :asc)
  end

  defp map_lap_data_to_relative_time(first_driver_data, other_driver_data) do
    for {lap_no, first_driver_lap_ts} <- first_driver_data,
        other_ts = find_lap_ts(other_driver_data, lap_no),
        other_ts != nil do
      delta = Timex.diff(other_ts, first_driver_lap_ts, :milliseconds) / 1000

      {lap_no, delta}
    end
  end

  defp find_lap_ts(driver_data, lap_no) do
    case Enum.find(driver_data, fn {n, _ts} -> lap_no == n end) do
      nil -> nil
      {_no, ts} -> ts
    end
  end
end
