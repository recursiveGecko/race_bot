defmodule F1Bot.F1Session.LiveTimingHandlers.TimingData do
  @moduledoc """
  Handler for lap times and sector times received from live timing API.
  The handler parses drivers' information and passes it on to the F1 session instance.
  """
  use TypedStruct

  require Logger
  alias F1Bot.F1Session.LiveTimingHandlers
  import LiveTimingHandlers.Helpers

  alias F1Bot.F1Session
  alias F1Bot.DataTransform.Parse
  alias LiveTimingHandlers.{Packet, ProcessingOptions, ProcessingResult}

  @type sector_times :: %{
          optional(1) => Timex.Duration.t(),
          optional(2) => Timex.Duration.t(),
          optional(3) => Timex.Duration.t()
        }

  typedstruct do
    field(:driver_number, pos_integer(), enforce: true)
    field(:timestamp, DateTime.t(), enforce: true)
    field(:lap_number, pos_integer() | nil)
    field(:lap_time, Timex.Duration.t() | nil)
    field(:sector_times, sector_times() | nil)
  end

  @behaviour LiveTimingHandlers
  @scope "TimingData"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(
        session,
        %Packet{
          topic: @scope,
          data: %{"Lines" => drivers = %{}},
          timestamp: timestamp
        },
        options
      ) do
    {session, events_nested} = handle_lines(session, drivers, timestamp, options)

    result = %ProcessingResult{
      session: session,
      events: List.flatten(events_nested)
    }

    {:ok, result}
  end

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(_session, _invalid_packet, _options) do
    {:error, :invalid_packet}
  end

  defp handle_lines(session, drivers, timestamp, options) do
    drivers
    |> Stream.map(fn {driver_num_str, data} ->
      case Integer.parse(driver_num_str) do
        {driver_number, ""} ->
          {driver_number, data}

        _ ->
          {nil, data}
      end
    end)
    |> Stream.filter(fn {driver_number, _data} -> driver_number != nil end)
    |> Enum.reduce({session, []}, fn line, acc ->
      handle_line(line, acc, timestamp, options)
    end)
  end

  defp handle_line(
         _line = {driver_number, data},
         _acc = {session, events},
         timestamp,
         options = %ProcessingOptions{}
       ) do
    maybe_log_driver_data("TimingData", driver_number, {timestamp, data}, options)

    lap_number = data["NumberOfLaps"]
    lap_time = maybe_extract_lap_time(data)
    sector_times = maybe_extract_sectors(data)

    timing_data = %__MODULE__{
      driver_number: driver_number,
      timestamp: timestamp,
      lap_number: lap_number,
      lap_time: lap_time,
      sector_times: sector_times
    }

    {session, new_events} =
      F1Session.push_timing_data(
        session,
        timing_data,
        !!options.skip_heavy_events
      )

    {session, [new_events | events]}
  end

  defp maybe_extract_lap_time(data) do
    lap_time_str = data["LastLapTime"]["Value"]

    if lap_time_str != nil and lap_time_str != "" do
      case Parse.parse_lap_time(lap_time_str) do
        {:ok, lap_time} ->
          lap_time

        {:error, _error} ->
          Logger.error("Error parsing lap time #{inspect(lap_time_str)}")
          nil
      end
    else
      nil
    end
  end

  def maybe_extract_sectors(_data = %{"Sectors" => sectors = %{}}) do
    result =
      ["0", "1", "2"]
      |> Enum.reduce(%{}, fn sector_str, acc ->
        sector_time_str = sectors[sector_str]["Value"]
        sector = String.to_integer(sector_str) + 1

        with true <- is_binary(sector_time_str),
             true <- sector_time_str != "",
             {:ok, sector_time} <- Parse.parse_lap_time(sector_time_str) do
          Map.put(acc, sector, sector_time)
        else
          {:error, _error} ->
            Logger.error("Error parsing sector time #{inspect(sector_time_str)}")
            acc

          _ ->
            acc
        end
      end)

    if result == %{} do
      nil
    else
      result
    end
  end

  def maybe_extract_sectors(_sectors), do: nil
end
