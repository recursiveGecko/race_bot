defmodule F1BotWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use F1BotWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import F1BotWeb.ChannelCase

      # The default endpoint for testing
      @endpoint F1BotWeb.Endpoint
    end
  end

  setup tags do
    F1Bot.DataCase.setup_sandbox(tags)
    :ok
  end

  defmacro assert_push_on_topic(topic, event, payload, timeout_ms) do
    quote location: :keep,
          bind_quoted: [timeout_ms: timeout_ms, topic: topic, event: event],
          unquote: true do
      assert_receive(
        %Phoenix.Socket.Message{
          topic: ^topic,
          event: ^event,
          payload: unquote(payload)
        },
        timeout_ms
      )
    end
  end
end
