defmodule F1BotWeb.RadioTranscriptChannelTest do
  use F1BotWeb.ChannelCase

  alias F1BotWeb.ApiSocket
  alias F1Bot.Authentication
  alias F1Bot.Authentication.ApiClient
  @moduletag :channel

  # Timeout for message assertions
  @ms_to 1000

  setup do
    {:ok, read_only_client} = Authentication.create_api_client("ro_client", [:read_transcripts])
    {:ok, unauth_client} = Authentication.create_api_client("unauth", [])

    {:ok, read_only_socket} = connect(ApiSocket, %{token: ApiClient.token(read_only_client)})
    {:ok, unauth_socket} = connect(ApiSocket, %{token: ApiClient.token(unauth_client)})

    %{
      read_only_client: read_only_client,
      read_only_socket: read_only_socket,
      unauth_client: unauth_client,
      unauth_socket: unauth_socket,
    }
  end

  describe "radio_transcript channel auth" do
    test "read_transcript client can join the channel", %{read_only_socket: read_only} do
      result = join(read_only, "radio_transcript:all")
      assert match?({:ok, _reply, _socket}, result)
    end

    test "other API clients can't join the channel", %{unauth_socket: unauth} do
      result = join(unauth, "radio_transcript:all")
      assert match?({:error, :unauthorized}, result)
    end
  end

  describe "status" do
    test "status is sent after joining :status subchannel", %{read_only_socket: socket} do
      {:ok, _reply, _socket} = subscribe_and_join(socket, "radio_transcript:status")

      assert_push("status", %{online: _, drivers: [_ | _]}, @ms_to)
    end
  end
end
