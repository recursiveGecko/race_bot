defmodule F1Bot.Repo.Migrations.AddApiClient do
  use Ecto.Migration

  def change do
    create table("api_client") do
      add :client_name, :string, null: false
      add :client_secret, :string, null: false
      add :scopes, :map, null: false
    end

    create index("api_client", [:client_name], unique: true)
  end
end
