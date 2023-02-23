defmodule F1Bot.F1Session.DriverDataRepo.Events do
  @moduledoc """
  Helper functions to generate events for `F1Bot.F1Session.DriverDataRepo` functions.
  """
  alias F1Bot.F1Session.Common.Event

  def make_agg_fastest_lap_event(driver_number, type, lap_time, lap_delta) do
    make_aggregate_stats_event(:fastest_lap, %{
      driver_number: driver_number,
      lap_time: lap_time,
      lap_delta: lap_delta,
      type: type
    })
  end

  def make_agg_fastest_sector_event(driver_number, type, sector, sector_time, sector_delta) do
    make_aggregate_stats_event(:fastest_sector, %{
      driver_number: driver_number,
      sector: sector,
      sector_time: sector_time,
      sector_delta: sector_delta,
      type: type
    })
  end

  def make_agg_top_speed_event(driver_number, type, speed, speed_delta) do
    make_aggregate_stats_event(:top_speed, %{
      driver_number: driver_number,
      speed: speed,
      speed_delta: speed_delta,
      type: type
    })
  end

  def make_tyre_change_events(
        driver,
        _result = %{is_correction: is_correction, stint: stint}
      ) do
    event =
      make_event(driver, :tyre_change, %{
        is_correction: is_correction,
        compound: stint.compound,
        age: stint.age
      })

    [event]
  end

  def make_tyre_change_events(_driver, _result = nil), do: []

  defp make_event(self, type, payload) do
    payload =
      payload
      |> Map.put(:driver_number, self.number)

    Event.new("driver:#{type}", payload)
  end

  defp make_aggregate_stats_event(type, payload) do
    Event.new("aggregate_stats:#{type}", payload)
  end
end
