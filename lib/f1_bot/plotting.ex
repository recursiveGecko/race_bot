defmodule F1Bot.Plotting do
  @moduledoc """
  """
  alias F1Bot.Plotting

  def plot_lap_times(driver_numbers, options \\ []) do
    Plotting.LapTime.plot(driver_numbers, options)
  end

  def plot_gap(driver_numbers, options \\ []) do
    Plotting.Gap.plot(driver_numbers, options)
  end

  def do_gnuplot(file_path, options, datasets) do
    case Gnuplot.plot(options, datasets) do
      {:ok, _commands} ->
        if check_file_ok(file_path) do
          {:ok, file_path}
        else
          cleanup(file_path)
          {:error, :file_not_created}
        end

      {:error, _, err} ->
        cleanup(file_path)
        {:error, err}
    end
  end

  def cleanup(file_path) do
    File.rm(file_path)
  end

  def check_file_ok(file_path) do
    case File.stat(file_path) do
      {:ok, %{size: size, type: type}} ->
        type == :regular and size > 0

      _ ->
        false
    end
  end

  def verify_datasets_nonempty(datasets) do
    all_points = List.flatten(datasets)

    if length(all_points) > 0 do
      :ok
    else
      :error
    end
  end

  def create_temp_file_path(extension) do
    charset = safe_chars()

    rand =
      for _ <- 1..20 do
        Enum.random(charset)
      end
      |> to_string()

    file_name = "f1_gnuplot_#{rand}.#{extension}"

    System.tmp_dir()
    |> Path.join(file_name)
  end

  defp safe_chars() do
    [?0..?9, ?a..?z, ?A..?Z]
    |> Enum.map_join(&Enum.to_list/1)
    |> to_charlist()
  end
end
