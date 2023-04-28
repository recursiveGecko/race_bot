defmodule F1Bot.Release do
  alias Ecto.Migrator
  require Logger

  @app :f1_bot

  def migrate() do
    for repo <- repos() do
      Logger.info("Migrating #{inspect(repo)}")
      {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    Logger.info("Rolling back migrations for #{inspect(repo)} to version #{version}")
    {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :down, to: version))
  end

  def repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
    |> IO.inspect()
  end
end
