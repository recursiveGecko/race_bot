defmodule F1Bot.F1Session.LiveTimingHandlers.Packet do
  @moduledoc """
  Struct that contains information about every packet received from the live timing API.

  Fields:

  - `:topic`: Websocket feed that the packet came from (e.g. car telemetry, lap times)
  - `:data`: Topic-specific payload
  - `:timestamp`: Timestamp of the packet, determined by the API
  - `:init`: Flag that determines whether this is an initialization packet received
  immediately after establishing websocket connection. This is useful for topics that
  contain static information, like driver names and session information.
  """
  use TypedStruct

  typedstruct do
    field(:topic, binary(), enforce: true)
    field(:data, any(), enforce: true)
    field(:timestamp, DateTime, enforce: true)
    field(:init, boolean(), default: false)
  end
end
