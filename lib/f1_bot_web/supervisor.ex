defmodule F1BotWeb.Supervisor do
  use Supervisor

  def start_link(_init_arg) do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_state) do
    children = [
      F1BotWeb.Endpoint,
      F1BotWeb.InternalEndpoint,
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
