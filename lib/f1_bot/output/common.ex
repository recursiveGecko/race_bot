defmodule F1Bot.Output.Common do
  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.{SessionInfo, DriverCache}

  @post_after_race_lap 5

  def should_post_stats(_event = %Event{session_info: session_info})
      when session_info != nil do
    lap = session_info.lap_number || 0
    is_race = SessionInfo.is_race?(session_info)

    lap > @post_after_race_lap or not is_race
  end

  def get_driver_name_by_number(_event = %Event{driver_cache: driver_cache}, driver_number) do
    case DriverCache.get_driver_by_number(driver_cache, driver_number) do
      {:ok, %{last_name: name}} -> name
      {:error, _} -> "Car #{driver_number}"
    end
  end

  def get_driver_abbr_by_number(_event = %Event{driver_cache: driver_cache}, driver_number) do
    case DriverCache.get_driver_by_number(driver_cache, driver_number) do
      {:ok, %{driver_abbr: abbr}} -> abbr
      {:error, _} -> "Car#{driver_number}"
    end
  end
end
