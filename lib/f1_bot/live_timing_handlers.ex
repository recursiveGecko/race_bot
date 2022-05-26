defmodule F1Bot.LiveTimingHandlers do
  @moduledoc """
  Entrypoint for all events ingested from F1 SignalR websocket API
  """
  use GenServer
  require Logger
  alias F1Bot.LiveTimingHandlers
  alias F1Bot.LiveTimingHandlers.Event

  @callback process_event(Event.t()) :: :ok | {:error, any()}

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: server_via())
  end

  @doc """
  Called by SignalR client for each received event.
  """
  def process_live_timing_event(event = %Event{}) do
    server_via()
    |> GenServer.call({:process_live_timing_event, event})
  end

  @impl true
  def init(_init_arg) do
    {:ok, nil}
  end

  @impl true
  def handle_call({:process_live_timing_event, event = %Event{}}, _from, state) do
    try do
      process_for_topic(state, event)
    rescue
      e ->
        err_text = Exception.format(:error, e, __STACKTRACE__)
        Logger.error("LiveTimingHandlers rescued an error. Details:\n#{err_text}")
    catch
      :exit, e ->
        err_text = Exception.format(:exit, e, __STACKTRACE__)
        Logger.error("LiveTimingHandlers caught an exit. Details:\n#{err_text}")
    end

    {:reply, :ok, state}
  end

  defp process_for_topic(_state, event = %Event{topic: "DriverList"}) do
    LiveTimingHandlers.DriverList.process_event(event)
    |> maybe_handle_error()
  end

  defp process_for_topic(_state, event = %Event{topic: "SessionInfo"}) do
    LiveTimingHandlers.SessionInfo.process_event(event)
    |> maybe_handle_error()
  end

  defp process_for_topic(_state, event = %Event{topic: "SessionStatus"}) do
    LiveTimingHandlers.SessionStatus.process_event(event)
    |> maybe_handle_error()
  end

  # Ignore initialization messages sent on other topics
  defp process_for_topic(_state, _event = %Event{init: true}) do
    :ignore
  end

  defp process_for_topic(_state, event = %Event{topic: "CarData"}) do
    LiveTimingHandlers.CarTelemetry.process_event(event)
    |> maybe_handle_error()
  end

  defp process_for_topic(_state, event = %Event{topic: "Position"}) do
    LiveTimingHandlers.PositionData.process_event(event)
    |> maybe_handle_error()
  end

  defp process_for_topic(_state, event = %Event{topic: "TimingData"}) do
    LiveTimingHandlers.LapData.process_event(event)
    |> maybe_handle_error()
  end

  defp process_for_topic(_state, event = %Event{topic: "RaceControlMessages"}) do
    LiveTimingHandlers.RaceControlMessages.process_event(event)
    |> maybe_handle_error()
  end

  defp process_for_topic(_state, event = %Event{topic: "TimingAppData"}) do
    LiveTimingHandlers.StintData.process_event(event)
    |> maybe_handle_error()
  end

  defp process_for_topic(_state, _event = %Event{topic: _topic}) do
    # Logger.warn("Received a message for unknown topic: #{topic}")
  end

  defp maybe_handle_error(result = {:error, error}) do
    Logger.error(error)
    result
  end

  defp maybe_handle_error(result) do
    result
  end

  defp server_via() do
    __MODULE__
  end
end
