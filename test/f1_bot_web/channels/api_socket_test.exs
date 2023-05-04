defmodule F1BotWeb.ApiSocketTest do
  use F1BotWeb.ChannelCase

  alias F1Bot.Authentication
  alias F1Bot.Authentication.ApiClient
  alias F1BotWeb.ApiSocket

  @moduletag :channel

  describe "authentication" do
    test "clients without token can't connect", _context do
      result = connect(ApiSocket, %{})
      assert match?({:error, :missing_token}, result)
    end

    test "clients with invalid token format can't connect", _context do
      result = connect(ApiSocket, %{token: "foo"})
      assert match?({:error, :invalid_token_format}, result)
    end

    test "clients with unknown token user can't connect", _context do
      result = connect(ApiSocket, %{token: "unknown_name:unknown_secret"})
      assert match?({:error, :unauthorized}, result)
    end

    test "clients with invalid client secret can't connect", _context do
      {:ok, client} = Authentication.create_api_client("test_client", [])
      result = connect(ApiSocket, %{token: "#{client.client_name}:unknown_secret"})
      assert match?({:error, :unauthorized}, result)
    end

    test "clients with a valid secret can connect", _context do
      {:ok, client} = Authentication.create_api_client("test_client", [])
      result = connect(ApiSocket, %{token: ApiClient.token(client)})
      assert match?({:ok, %Phoenix.Socket{}}, result)
    end
  end
end
