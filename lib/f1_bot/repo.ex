defmodule F1Bot.Repo do
  use Ecto.Repo,
    otp_app: :f1_bot,
    adapter: Ecto.Adapters.SQLite3
end
