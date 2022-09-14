defmodule F1Bot.F1Session.Clock do
  use TypedStruct

  typedstruct do
    field :utc_server_time_sync, DateTime.t()
    field :utc_local_time_sync, DateTime.t()
    field :session_clock, Timex.Duration.t()
    field :is_running, boolean()
  end

  def new(server_time, local_time, session_clock, is_running) do
    %__MODULE__{
      utc_server_time_sync: server_time,
      utc_local_time_sync: local_time,
      session_clock: session_clock,
      is_running: is_running
    }
  end

  def session_clock_from_server_time(clock, server_time) do
    if clock.is_running do
      time_since_clock_started = Timex.diff(server_time, clock.utc_server_time_sync, :duration)

      remaining =
        clock.session_clock
        |> Timex.Duration.sub(time_since_clock_started)

      if Timex.Duration.to_milliseconds(remaining) < 0 do
        Timex.Duration.from_seconds(0)
      else
        remaining
      end
    else
      clock.session_clock
    end
  end

  def session_clock_from_local_time(clock, local_time) do
    local_time_delta = Timex.diff(local_time, clock.utc_local_time_sync, :duration)
    server_time = Timex.add(clock.utc_server_time_sync, local_time_delta)

    session_clock_from_server_time(clock, server_time)
  end
end
