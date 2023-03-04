defmodule F1Bot.F1Session.LiveTimingHandlers.ProcessingOptions do
  @moduledoc """
  Packet processing options.

  Fields:
    - `:ignore_reset` - If true, session reset mechanisms won't fire. This is useful for
      processing session replays
    - `:log_stray_packets` - If true, packets received while session is inactive will be logged.
    - `:log_drivers` - Packets related to specified drivers will be logged to console and log file.
    - `:local_time_fn` - 0-arity function to get the current local time for the purposes of packet processing.
      This can be overriden so that server time ("Utc" field in many Packets) is used in place of local system time,
      useful when replaying sessions where current local time is irrelevant and leads to inconsistencies such
      as the session clock not being reported correctly due to nearly instant passage of time.
    - `:skip_heavy_events` - If true, events such as driver summaries won't be created, this is useful
      during session replays to speed up processing time.
  """
  use TypedStruct

  typedstruct do
    field(:ignore_reset, boolean())
    field(:log_stray_packets, boolean())
    field(:log_drivers, [integer()])
    field(:local_time_fn, function())
    field(:skip_heavy_events, boolean())
  end

  def new(), do: %__MODULE__{}

  def merge(a = %__MODULE__{}, b = %__MODULE__{}) do
    MapUtils.patch_ignore_nil(a, b)
  end
end
