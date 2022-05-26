defmodule F1Bot.F1Session.Server do
  @moduledoc """
  GenServer that holds the live `F1Bot.F1Session.Impl` instance, coordinates data processing
  for incoming live timing events and executes all side effects by passing event messages to
  `F1Bot.Output.Discord` and `F1Bot.Output.Twitter` via PubSub.
  """
  use GenServer
  require Logger

  alias F1Bot.F1Session.Impl
  alias F1Bot.F1Session.Common.Helpers

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: server_via())
  end

  @impl true
  def init(_init_arg) do
    state = %{
      session: Impl.new()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_session_info}, _from, state = %{session: session}) do
    reply =
      case session.session_info.type do
        nil -> {:error, :no_session_info}
        _ -> {:ok, session.session_info}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:get_session_status}, _from, state = %{session: session}) do
    reply =
      case session.session_status do
        nil -> {:error, :not_available}
        status -> {:ok, status}
      end

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:get_driver_info, driver_number}, _from, state = %{session: session}) do
    reply = Impl.driver_info_by_number(session, driver_number)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:get_driver_info_by_abbr, driver_number}, _from, state = %{session: session}) do
    reply = Impl.driver_info_by_abbr(session, driver_number)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:get_driver_session_data, driver_number}, _from, state = %{session: session}) do
    data = Impl.driver_session_data(session, driver_number)
    reply = {:ok, data}
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:push_telemetry, driver_number, channels}, _from, state = %{session: session}) do
    session = Impl.push_telemetry(session, driver_number, channels)
    state = %{state | session: session}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:push_position, driver_number, position}, _from, state = %{session: session}) do
    session = Impl.push_position(session, driver_number, position)
    state = %{state | session: session}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(
        {:push_lap_time, driver_number, lap_time, timestamp},
        _from,
        state = %{session: session}
      ) do
    {session, events} = Impl.push_lap_time(session, driver_number, lap_time, timestamp)
    state = %{state | session: session}

    Helpers.publish_events(events)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(
        {:push_lap_number, driver_number, lap_number, timestamp},
        _from,
        state = %{session: session}
      ) do
    session = Impl.push_lap_number(session, driver_number, lap_number, timestamp)
    state = %{state | session: session}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:push_race_control_messages, messages}, _from, state = %{session: session}) do
    {session, events} = Impl.push_race_control_messages(session, messages)
    state = %{state | session: session}

    Helpers.publish_events(events)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:push_session_info, session_info}, _from, state = %{session: session}) do
    Logger.info("Session info updated: #{inspect(session_info, pretty: true)}")

    session = Impl.push_session_info(session, session_info)
    state = %{state | session: session}
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:push_session_status, session_status}, _from, state = %{session: session}) do
    {session, events} = Impl.push_session_status(session, session_status)
    state = %{state | session: session}

    Helpers.publish_events(events)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(
        {:push_stint_data, driver_number, stint_data},
        _from,
        state = %{session: session}
      ) do
    {session, events} = Impl.push_stint_data(session, driver_number, stint_data)
    state = %{state | session: session}

    Helpers.publish_events(events)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:push_driver_list_update, drivers}, _from, state = %{session: session}) do
    session = Impl.push_driver_list_update(session, drivers)
    state = %{state | session: session}
    {:reply, :ok, state}
  end

  def server_via() do
    __MODULE__
  end
end
