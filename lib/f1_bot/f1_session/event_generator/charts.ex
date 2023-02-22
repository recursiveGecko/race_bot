defmodule F1Bot.F1Session.EventGenerator.Charts do
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.SessionInfo
  alias F1Bot.Analysis.GraphSpec

  def chart_init_events(session = %F1Session{}), do: chart_init_events(session.session_info)

  def chart_init_events(session_info = %SessionInfo{}) do
    is_race = SessionInfo.is_race?(session_info)

    lap_time_chart =
      if is_race do
        "lap_times_race"
      else
        "lap_times_quali"
      end

    event_name = "#{session_info.gp_name} (#{session_info.type})"

    lap_time_init_payload = %{
      spec: GraphSpec.load!(lap_time_chart) |> replace_title("Lap times at #{event_name}")
    }

    [
      Event.new(:chart_init, :lap_times, lap_time_init_payload)
    ]
  end

  defp replace_title(spec, title) do
    put_in(spec, ["title"], title)
  end
end
