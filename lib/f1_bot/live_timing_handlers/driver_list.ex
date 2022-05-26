defmodule F1Bot.LiveTimingHandlers.DriverList do
  @moduledoc """
  Handler for driver list updates received from live timing API.

  The handler parses driver information and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.F1Session.DriverCache.DriverInfo
  alias F1Bot.LiveTimingHandlers.Event
  @scope "DriverList"

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: data
      }) do
    parsed_drivers =
      for {driver_no, driver_json} <- data, is_map(driver_json) do
        driver_json =
          driver_json
          |> Map.put_new("RacingNumber", driver_no)
          |> Map.update("RacingNumber", nil, fn x -> x |> String.trim() |> String.to_integer() end)

        DriverInfo.parse_from_json(driver_json)
      end

    F1Bot.F1Session.push_driver_list_update(parsed_drivers)

    :ok
  end
end
