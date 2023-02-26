defmodule F1Bot.F1Session.EventGenerator.Driver do
  alias F1Bot.Analysis
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.DriverDataRepo.Lap

  def on_any_new_driver_data(session, driver_number) do
    [
      summary_events(session, driver_number)
    ]
    |> List.flatten()
  end

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

  def lap_time_chart_events(session, driver_number, lap_or_nil \\ nil)

  def lap_time_chart_events(session = %F1Session{}, driver_number, lap)
      when is_integer(driver_number) and (is_nil(lap) or is_struct(lap, Lap)) do
    common_payload = %{
      dataset: "driver_data"
    }

    data_init_events =
      with {:ok, data} <- Analysis.LapTimes.calculate(session, driver_number),
           {:ok, driver_meta} <- fetch_driver_metadata(driver_number, session) do
        payload =
          common_payload
          |> Map.put(:data, data)
          |> Map.merge(driver_meta)

        e = Event.new("lap_time_chart_data_init:#{driver_number}", payload)
        [e]
      else
        _ ->
          []
      end

    data_init_events
  end

  defp fetch_driver_metadata(driver_number, session = %F1Session{}) do
    with {:ok, info} <- F1Session.driver_info_by_number(session, driver_number) do
      p = %{
        driver_name: info.last_name,
        driver_number: driver_number,
        driver_abbr: info.driver_abbr,
        team_color: info.team_color,
        chart_team_order: info.chart_team_order,
        chart_order: info.chart_order
      }

      {:ok, p}
    end
  end
end
