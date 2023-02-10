defmodule F1Bot.F1Session.EventGenerator.Driver do
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event

  def summary_events(session = %F1Session{}, driver_number)
      when is_integer(driver_number) do
    with {:ok, summary} <- F1Session.driver_summary(session, driver_number),
         {:ok, session_best_stats} <- F1Session.session_best_stats(session) do
      payload = %{
        driver_number: driver_number,
        driver_summary: summary,
        session_best_stats: Map.from_struct(session_best_stats)
      }

      scope = :"driver:#{driver_number}"
      [Event.new(scope, :summary, payload)]
    else
      {:error, _} -> []
    end
  end
end
