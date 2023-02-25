defmodule F1Bot.F1Session.EventGenerator.Charts do
  alias F1Bot.F1Session
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.SessionInfo

  def chart_init_events(session = %F1Session{}), do: chart_init_events(session.session_info)

  def chart_init_events(session_info = %SessionInfo{}) do
    is_race = SessionInfo.is_race?(session_info)

    lap_time_chart_class =
      # Must match a class from /assets/js/Visualizations
      if is_race do
        "RaceLapTimeChart"
      else
        "x"
      end

    [
      Event.new("chart_init:lap_times", lap_time_chart_class)
    ]
  end
end
