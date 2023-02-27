defmodule F1Bot.F1Session.LiveTimingHandlers.DriverList do
  @moduledoc """
  Handler for driver list updates received from live timing API.

  The handler parses driver information and passes it on to the F1 session instance.
  """
  require Logger
  alias F1Bot.F1Session.LiveTimingHandlers
  import LiveTimingHandlers.Helpers

  alias F1Bot.F1Session
  alias F1Session.DriverCache.DriverInfo
  alias LiveTimingHandlers.{Packet, ProcessingResult}

  @behaviour LiveTimingHandlers
  @scope "DriverList"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(
        session,
        %Packet{
          topic: @scope,
          data: data
        },
        options
      ) do
    parsed_drivers =
      for {driver_no, driver_json} <- data, is_map(driver_json) do
        driver_number = driver_json["RacingNumber"] || driver_no
        driver_number = driver_number |> String.trim() |> String.to_integer()
        driver_json = Map.put(driver_json, "RacingNumber", driver_number)

        maybe_log_driver_data("Driver info", driver_number, driver_json, options)

        DriverInfo.parse_from_json(driver_json)
      end

    {session, events} = F1Session.push_driver_list_update(session, parsed_drivers)

    result = %ProcessingResult{
      session: session,
      events: events
    }

    {:ok, result}
  end
end
