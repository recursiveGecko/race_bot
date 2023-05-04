Logger.configure(level: :info)
ExUnit.start(exclude: [skip_inconclusive: true], capture_log: true)
Ecto.Adapters.SQL.Sandbox.mode(F1Bot.Repo, :manual)
