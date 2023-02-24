defmodule F1Bot.F1Session.Common.Event do
  @moduledoc ""
  use TypedStruct

  alias F1Bot.F1Session

  typedstruct do
    @typedoc "Emitted state machine event"

    field(:scope, binary(), enforce: true)
    field(:payload, any(), enforce: true)
    field(:timestamp, integer())
    field(:meta, map())
  end

  @spec new(binary(), any()) :: t()
  def new(scope, payload) do
    %__MODULE__{
      scope: scope,
      payload: payload,
      timestamp: System.monotonic_time(:millisecond)
    }
  end

  def attach_driver_info(events, session, driver_numbers) when is_list(events) do
    driver_info_map =
      for driver_no <- driver_numbers, into: %{} do
        driver_info =
          case F1Session.driver_info_by_number(session, driver_no) do
            {:ok, info} -> info
            {:error, _} -> nil
          end

        {driver_no, driver_info}
      end

    for e <- events do
      existing_meta = e.meta || %{}
      new_meta = Map.merge(existing_meta, %{driver_info: driver_info_map})
      %{e | meta: new_meta}
    end
  end

  def attach_session_info(events, session = %F1Session{}) when is_list(events) do
    new_meta = %{
      lap_number: session.lap_counter.current,
      session_type: session.session_info.type,
    }

    for e <- events do
      existing_meta = e.meta || %{}
      meta = Map.merge(existing_meta, new_meta)

      Map.put(e, :meta, meta)
    end
  end
end
