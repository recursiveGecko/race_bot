defmodule F1Bot.F1Session.LiveTimingHandlers.ExtrapolatedClock do
  @moduledoc """
  Handler for extrapolated clock which keeps track of remaining session time,
  useful for qualifying.
  """
  require Logger
  @behaviour F1Bot.F1Session.LiveTimingHandlers

  alias F1Bot.DataTransform.Parse
  alias F1Bot.F1Session
  alias F1Bot.F1Session.LiveTimingHandlers.Packet
  @scope "ExtrapolatedClock"

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(session, %Packet{
        topic: @scope,
        data: data = %{"Remaining" => remaining, "Utc" => utc}
      }) do
    with {:ok, remaining} <- Parse.parse_session_clock(remaining),
         {:ok, server_time} <- Timex.parse(utc, "{ISO:Extended}") do
      local_time = Timex.now()
      is_running = !!data["Extrapolating"]
      session = F1Session.update_clock(session, server_time, local_time, remaining, is_running)
      {:ok, session, []}
    else
      {:error, error} ->
        Logger.error("Failed to parse extrapolated clock: #{inspect(error)}")
        {:ok, session, []}
    end
  end

  @impl F1Bot.F1Session.LiveTimingHandlers
  def process_packet(_session, %Packet{
        topic: @scope,
        data: data
      }) do
    {:error, {:invalid_clock_data, data}}
  end
end
