defmodule F1Bot.Output.Common do
  alias F1Bot.F1Session.Common.Event

  @post_after_race_lap 5

  def should_post_stats(_event = %Event{meta: meta})
      when meta != nil do
    lap = meta.lap_number || 0
    is_race = meta.session_type == "Race"

    lap > @post_after_race_lap or not is_race
  end

  def get_driver_name_by_number(_event = %Event{meta: meta}, driver_number) do
    case meta[:driver_info][driver_number] do
      %{last_name: name} when name != nil -> name
      %{short_name: name} when name != nil -> name
      %{driver_abbr: name} when name != nil -> name
      _ -> "Car #{driver_number}"
    end
  end

  def get_driver_abbr_by_number(_event = %Event{meta: meta}, driver_number) do
    case meta[:driver_info][driver_number] do
      %{driver_abbr: abbr} -> abbr
      %{last_name: name} when name != nil -> name
      %{short_name: name} when name != nil -> name
      _ -> "Car #{driver_number}"
    end
  end
end
