defmodule F1Bot.Authentication do
  import Ecto.Query
  alias F1Bot.Repo
  alias F1Bot.Authentication.ApiClient

  def create_api_client(name, scopes) do
    params = %{
      client_name: name,
      scopes: scopes
    }

    params
    |> ApiClient.create_changeset()
    |> Repo.insert()
  end

  def find_api_client_by_name(name) do
    query =
      from(c in ApiClient,
        where: c.client_name == ^name
      )

    case Repo.one(query) do
      nil -> {:error, :not_found}
      client -> {:ok, client}
    end
  end

  def delete_api_client_by_name(name) do
    query =
      from(c in ApiClient,
        where: c.client_name == ^name
      )

    {count, _} = Repo.delete_all(query)
    count > 0
  end
end
