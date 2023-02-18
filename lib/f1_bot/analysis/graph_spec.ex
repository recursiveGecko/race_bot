defmodule F1Bot.Analysis.GraphSpec do
  use Memoize

  @allowed_file_names [
    "gap_to_leader",
    "lap_times_quali",
    "lap_times_race"
  ]

  defmemo load(file_name) do
    if file_name in @allowed_file_names do
      with {:ok, json_spec} <- load_from_file(file_name) do
        json_spec = remove_dummy_datasets(json_spec)
        {:ok, json_spec}
      end
    else
      {:error, :invalid_file_name}
    end
  end

  defp remove_dummy_datasets(json_spec) do
    json_spec
    |> Map.update("datasets", %{}, fn datasets ->
      datasets
      |> Enum.map(fn {key, _} -> {key, []} end)
      |> Enum.into(%{})
    end)
  end

  defmemop load_from_file(file_name) do
    :f1_bot
    |> Application.app_dir("priv/vega/#{file_name}.json")
    |> File.read()
    |> case do
      {:ok, json} -> Jason.decode(json)
      {:error, reason} -> {:error, reason}
    end
  end
end
