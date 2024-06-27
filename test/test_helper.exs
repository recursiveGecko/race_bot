Logger.configure(level: :info)

ExUnit.start(
  exclude: [skip_inconclusive: true, uses_live_timing_data: true],
  capture_log: true
)

Ecto.Adapters.SQL.Sandbox.mode(F1Bot.Repo, :manual)
