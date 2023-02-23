defmodule F1Bot.F1Session.EventGenerator.Driver do
  alias F1Bot.Analysis
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.DriverDataRepo.Lap

  def summary_events(session = %F1Session{}, driver_number)
      when is_integer(driver_number) do
    with {:ok, summary} <- F1Session.driver_summary(session, driver_number),
         {:ok, session_best_stats} <- F1Session.session_best_stats(session) do
      payload = %{
        driver_number: driver_number,
        driver_summary: summary,
        session_best_stats: Map.from_struct(session_best_stats)
      }

      scope = "driver_summary:#{driver_number}"
      [Event.new(scope, payload)]
    else
      {:error, _} -> []
    end
  end

  def lap_time_chart_events(session = %F1Session{}, driver_number, lap = %Lap{})
      when is_integer(driver_number) do
    dataset_name = "driver_data"

    data_init_events =
      case Analysis.LapTimes.generate_vegalite_dataset(session, [driver_number]) do
        {:ok, dataset} ->
          payload = %{dataset: dataset_name, data: dataset}
          e = Event.new("lap_time_chart_data_init:#{driver_number}", payload)
          [e]

        _ ->
          []
      end

    data_delta_events =
      case Analysis.LapTimes.lap_to_vegalite_datum(lap, driver_number, session) do
        {:ok, datum} ->
          payload = %{dataset: dataset_name, data: [datum]}
          e = Event.new("lap_time_chart_data_delta:#{driver_number}", payload)
          [e]

        _ ->
          []
      end

    [data_init_events, data_delta_events]
    |> List.flatten()
  end
end
