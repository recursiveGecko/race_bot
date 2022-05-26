defmodule F1Bot.LiveTimingHandlers.StintData do
  @moduledoc """
  Handler for stint information (tyre changes) received from live timing API.

  The handler parses the stint data and passes it on to the F1 session instance.
  """
  require Logger
  @behaviour F1Bot.LiveTimingHandlers

  alias F1Bot.LiveTimingHandlers.Event
  @scope "TimingAppData"

  @impl F1Bot.LiveTimingHandlers
  def process_event(%Event{
        topic: @scope,
        data: %{"Lines" => drivers = %{}},
        timestamp: _timestamp
      }) do
    drivers
    |> Enum.filter(fn {_, data} -> data["Stints"] |> is_map() end)
    |> Enum.each(fn {driver_number, %{"Stints" => stints}} ->
      driver_number = String.trim(driver_number) |> String.to_integer()

      for {stint_number_str, stint_data} <- stints,
          compound = stint_data["Compound"],
          compound not in ["UNKNOWN", nil] do
        stint_data = %{
          number: String.to_integer(stint_number_str),
          compound: compound |> String.downcase() |> String.to_atom(),
          age: Map.get(stint_data, "StartLaps", 0),
          tyres_changed: stint_data["TyresNotChanged"] == "0"
        }

        F1Bot.F1Session.push_stint_data(driver_number, stint_data)
      end
    end)

    :ok
  end
end
