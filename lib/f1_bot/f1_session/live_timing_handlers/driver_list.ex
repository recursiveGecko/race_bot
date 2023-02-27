defmodule F1Bot.F1Session.LiveTimingHandlers.DriverList do
  @moduledoc """
  Handler for driver list updates received from live timing API.

  The handler parses driver information and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.F1Session
  alias F1Bot.F1Session.DriverCache.DriverInfo
  alias F1Bot.F1Session.LiveTimingHandlers.{Packet, ProcessingResult}

  @scope "DriverList"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(
        session,
        %Packet{
          topic: @scope,
          data: data
        },
        _options
      ) do
    parsed_drivers =
      for {driver_no, driver_json} <- data, is_map(driver_json) do
        driver_json =
          driver_json
          |> Map.put_new("RacingNumber", driver_no)
          |> Map.update("RacingNumber", nil, fn x -> x |> String.trim() |> String.to_integer() end)

        # |> Map.update("HeadshotUrl", nil, &String.replace(&1, ~r|\.transform\/.*|, ""))

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
