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

  def list_all_api_clients() do
    Repo.all(ApiClient)
  end

  def find_api_client_by_name(name) do
    query =
      ApiClient
      |> where([c], c.client_name == ^name)

    case Repo.one(query) do
      nil -> {:error, :not_found}
      client -> {:ok, client}
    end
  end

  def update_api_client_scopes(data = %ApiClient{}, scopes) do
    data
    |> ApiClient.update_changeset(%{scopes: scopes})
    |> Repo.update()
  end

  def delete_api_client_by_name(name) do
    query =
      ApiClient
      |> where([c], c.client_name == ^name)

    {count, _} = Repo.delete_all(query)
    count > 0
  end
end
