defmodule F1Bot.DelayedEvents.Supervisor do
  use Supervisor

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children =
      for delay_ms <- F1Bot.DelayedEvents.available_delays() do
        init_arg = [
          delay_ms: delay_ms,
        ]

        module = F1Bot.DelayedEvents.Rebroadcaster

        %{
          id: :"#{module}::#{delay_ms}",
          start: {module, :start_link, [init_arg]}
        }
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
