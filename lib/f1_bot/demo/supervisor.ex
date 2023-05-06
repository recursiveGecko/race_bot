defmodule F1Bot.Demo.Supervisor do
  use Supervisor
  alias F1Bot.Demo

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      Demo.FakeRadioGenerator,
      {Task, &start_demo_mode_replay/0},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp start_demo_mode_replay() do
    url = F1Bot.demo_mode_url()
    F1Bot.Replay.Server.start_replay(url, 1, true)
  end
end
