defmodule F1Bot.F1Session.Common.Event do
  @moduledoc ""
  use TypedStruct

  alias F1Bot.F1Session

  @type event_scope :: :driver | :aggregate_stats | :session_status | :race_control
  @type event_type ::
          :fastest_lap
          | :fastest_sector
          | :top_speed
          | :tyre_change
          | :started
          | :message

  typedstruct do
    @typedoc "Emitted state machine event"

    field(:scope, event_scope(), enforce: true)
    field(:type, event_type(), enforce: true)
    field(:payload, any(), enforce: true)
    field(:session_status, atom())
    field(:session_info, F1Session.SessionInfo.t())
    field(:driver_cache, F1Session.DriverCache.t())
  end

  @spec new(event_scope(), event_type(), any()) :: t()
  def new(scope, type, payload) do
    %__MODULE__{
      scope: scope,
      type: type,
      payload: payload
    }
  end
end
