defmodule F1Bot.Demo.FakeRadioGenerator do
  use GenServer

  alias F1Bot.F1Session.Server
  alias F1Bot.F1Session.DriverDataRepo.Transcript
  alias F1Bot.DataTransform.Format

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    F1Bot.PubSub.subscribe_to_event("aggregate_stats:fastest_sector")
    F1Bot.PubSub.subscribe_to_event("aggregate_stats:fastest_lap")
    {:ok, nil}
  end

  @impl true
  def handle_info(
        _e = %{
          scope: "aggregate_stats:fastest_sector",
          payload: %{
            driver_number: driver_number,
            type: type,
            sector: sector,
            sector_time: sector_time
          }
        },
        state
      ) do
    sector_time = Format.format_lap_time(sector_time, true)

    prefix =
      case type do
        :personal -> "New PB in sector #{sector}"
        :overall -> "Fastest sector #{sector} out of anyone"
      end

    msg = "#{prefix}, #{sector_time}"

    # TODO: Get session time
    utc_then = DateTime.utc_now()

    transcript = %Transcript{
      id: Ecto.UUID.generate(),
      driver_number: driver_number,
      duration_sec: 5,
      utc_date: utc_then,
      playhead_utc_date: utc_then,
      estimated_real_date: utc_then,
      message: msg,
      meeting_session_key: 0,
      meeting_key: 0
    }

    Server.process_transcript(transcript)
    Transcript.broadcast_to_channels(transcript)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        _e = %{
          scope: "aggregate_stats:fastest_lap",
          payload: %{
            driver_number: driver_number,
            type: type,
            lap_time: lap_time
          }
        },
        state
      ) do
    lap_time = Format.format_lap_time(lap_time, true)

    prefix =
      case type do
        :personal -> "You just set a new PB"
        :overall -> "That's P1, you just set the fastest lap"
      end

    msg = "#{prefix}, #{lap_time}"

    # TODO: Get session time
    utc_then = DateTime.utc_now()

    transcript = %Transcript{
      driver_number: driver_number,
      duration_sec: 5,
      utc_date: utc_then,
      playhead_utc_date: utc_then,
      estimated_real_date: utc_then,
      message: msg,
      meeting_session_key: 0,
      meeting_key: 0
    }

    Server.process_transcript(transcript)
    Transcript.broadcast_to_channels(transcript)

    {:noreply, state}
  end
end
