defmodule F1Bot.TranscriberService do
  use GenServer
  @timeout_ms 15_000

  defmodule Status do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      field(:online, :boolean, default: true)

      embeds_many :drivers, DriverStatus, primary_key: false do
        field(:driver_number, :integer)
        field(:online, :boolean)
      end
    end

    def new() do
      %__MODULE__{
        online: false,
        drivers: []
      }
    end

    def validate(params) do
      %__MODULE__{}
      |> cast(params, [:online])
      |> cast_embed(:drivers, with: &validate_driver/2)
      |> validate_required([:online])
      |> apply_action(:validate)
    end

    def validate_driver(data, params) do
      data
      |> cast(params, [:driver_number, :online])
      |> validate_required([:driver_number, :online])
    end
  end

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    state = %{
      status: Status.new(),
      last_ping: DateTime.from_unix!(0)
    }

    :timer.send_interval(5_000, :timeout_watchdog)

    {:ok, state}
  end

  def status() do
    GenServer.call(__MODULE__, {:status})
  end

  def ping() do
    GenServer.call(__MODULE__, {:ping})
  end

  def update_status(status = %Status{}) do
    GenServer.call(__MODULE__, {:update_status, status})
  end

  @impl true
  def handle_call({:status}, _from, state) do
    {:reply, state_to_status(state), state}
  end

  @impl true
  def handle_call({:update_status, status = %Status{}}, _from, state) do
    new_state =
      state
      |> update_last_ping()
      |> Map.put(:status, status)

    maybe_broadcast_update(state, new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:timeout_watchdog, state) do
    new_state = check_update_status(state)

    maybe_broadcast_update(state, new_state)
    {:noreply, new_state}
  end

  defp update_last_ping(state) do
    %{state | last_ping: DateTime.utc_now()}
  end

  defp check_update_status(state) do
    now = DateTime.utc_now()
    timed_out = DateTime.diff(now, state.last_ping, :millisecond) > @timeout_ms

    status =
      if timed_out do
        %{
          state.status
          | online: false,
            drivers: Enum.map(state.status.drivers, fn d -> %{d | online: not timed_out} end)
        }
      else
        state.status
      end

    %{state | status: status}
  end

  defp maybe_broadcast_update(_old_state, new_state) do
    status = state_to_status(new_state)
    F1BotWeb.Endpoint.broadcast("radio_transcript:status", "status", status)
  end

  defp state_to_status(state) do
    state.status
  end
end
