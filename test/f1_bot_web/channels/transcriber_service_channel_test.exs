defmodule F1BotWeb.TranscriberServiceChannelTest do
  use F1BotWeb.ChannelCase

  alias F1BotWeb.ApiSocket
  alias F1Bot.Authentication
  alias F1Bot.Authentication.ApiClient
  alias F1Bot.TranscriberService.Status
  alias F1Bot.F1Session.DriverDataRepo.Transcript
  @moduletag :channel

  # Timeout for message assertions
  @ms_to 5000

  setup do
    {:ok, transcriber_service} =
      Authentication.create_api_client("service", [:transcriber_service])

    {:ok, read_only_client} = Authentication.create_api_client("ro_client", [:read_transcripts])

    {:ok, transcriber_socket} = connect(ApiSocket, %{token: ApiClient.token(transcriber_service)})
    {:ok, read_only_socket} = connect(ApiSocket, %{token: ApiClient.token(read_only_client)})

    %{
      transcriber_service: transcriber_service,
      transcriber_socket: transcriber_socket,
      read_only_client: read_only_client,
      read_only_socket: read_only_socket
    }
  end

  describe "transcriber_service channel auth" do
    test "transcriber service can join the channel", %{transcriber_socket: transcriber} do
      result = join(transcriber, "transcriber_service")
      assert match?({:ok, _reply, _socket}, result)
    end

    test "other API clients can't join the channel", %{read_only_socket: read_only} do
      result = join(read_only, "transcriber_service")
      assert match?({:error, :unauthorized}, result)
    end
  end

  describe "transcripts" do
    setup %{
      transcriber_socket: transcriber_socket,
      read_only_socket: read_only_socket
    } do
      valid_transcript_data = %{
        driver_number: 999,
        utc_date: DateTime.utc_now() |> DateTime.to_iso8601(),
        message: "Hello world",
        duration_sec: 5.9
      }

      {:ok, transcript} = Transcript.validate(valid_transcript_data)

      {:ok, _reply, transcriber_socket} = join(transcriber_socket, "transcriber_service")
      {:ok, _reply, read_only_socket} = join(read_only_socket, "radio_transcript:999")
      {:ok, _reply, read_only_all_socket} = join(read_only_socket, "radio_transcript:all")

      %{
        transcriber_socket: transcriber_socket,
        read_only_socket: read_only_socket,
        read_only_all_socket: read_only_all_socket,
        valid_transcript_data: valid_transcript_data,
        valid_transcript: transcript
      }
    end

    test "invalid transcripts are rejected", %{transcriber_socket: transcriber} do
      ref = push(transcriber, "transcript", %{})
      assert_reply(ref, :error, :invalid_data, @ms_to)
    end

    test "valid transcripts are accepted", %{
      transcriber_socket: transcriber,
      valid_transcript_data: valid_transcript_data
    } do
      ref = push(transcriber, "transcript", valid_transcript_data)
      assert_reply(ref, :ok, %{}, @ms_to)
    end

    test "transcripts are broadcast to the :all subchannel", %{
      transcriber_socket: transcriber,
      valid_transcript_data: valid_transcript_data
    } do
      @endpoint.subscribe("radio_transcript:all")

      ref = push(transcriber, "transcript", valid_transcript_data)
      assert_reply(ref, :ok, %{}, @ms_to)

      assert_broadcast("transcript", %Transcript{}, @ms_to)
    end

    test "transcripts are broadcast to the driver subchannel", %{
      transcriber_socket: transcriber,
      valid_transcript_data: valid_transcript_data
    } do
      @endpoint.subscribe("radio_transcript:#{valid_transcript_data.driver_number}")

      ref = push(transcriber, "transcript", valid_transcript_data)
      assert_reply(ref, :ok, %{}, @ms_to)

      assert_broadcast("transcript", %Transcript{}, @ms_to)
    end

    test "transcripts in :all subchannel are pushed to the clients", %{
      transcriber_socket: transcriber,
      valid_transcript_data: valid_transcript_data
    } do
      ref = push(transcriber, "transcript", valid_transcript_data)
      assert_reply(ref, :ok, %{}, @ms_to)

      expected_topic = "radio_transcript:all"
      assert_push_on_topic(expected_topic, "transcript", %Transcript{}, @ms_to)
    end

    test "transcripts are pushed to the clients in driver subchannel", %{
      transcriber_socket: transcriber,
      valid_transcript_data: valid_transcript_data
    } do
      ref = push(transcriber, "transcript", valid_transcript_data)
      assert_reply(ref, :ok, %{}, @ms_to)

      expected_topic = "radio_transcript:#{valid_transcript_data.driver_number()}"
      assert_push_on_topic(expected_topic, "transcript", %Transcript{}, @ms_to)
    end
  end

  describe "status update" do
    setup %{
      transcriber_socket: transcriber_socket,
      read_only_socket: read_only_socket
    } do
      {:ok, _reply, transcriber_socket} = join(transcriber_socket, "transcriber_service")
      {:ok, _reply, read_only_socket} = join(read_only_socket, "radio_transcript:status")

      %{
        transcriber_socket: transcriber_socket,
        read_only_socket: read_only_socket
      }
    end

    test "invalid status updates are rejected", %{transcriber_socket: transcriber} do
      ref = push(transcriber, "update-status", %{online: "invalid"})
      assert_reply(ref, :error, :invalid_data, @ms_to)
    end

    test "service status updates are pushed to the clients", %{transcriber_socket: transcriber} do
      status_update = %{
        online: true,
        drivers: [
          %{driver_number: 999, online: true},
          %{driver_number: 800, online: false}
        ]
      }

      ref = push(transcriber, "update-status", status_update)
      assert_reply(ref, :ok, %{}, @ms_to)

      assert_push_on_topic(
        "radio_transcript:status",
        "status",
        %Status{
          online: true,
          drivers: [
            %{driver_number: 999, online: true},
            %{driver_number: 800, online: false}
          ]
        },
        @ms_to
      )
    end
  end
end
