defmodule F1Bot.F1Session.LiveTimingHandlers.ProcessingOptions do
  @moduledoc """
  Packet processing options.

  Fields:
    - `:ignore_reset` - If true, session reset mechanisms won't fire. This is useful for
      processing session replays
    - `:log_stray_packets` - If true, packets received while session is inactive will be logged.
    - `:log_drivers` - Packets related to specified drivers will be logged to console and log file.
  """
  use TypedStruct

  typedstruct do
    field(:ignore_reset, boolean())
    field(:log_stray_packets, boolean())
    field(:log_drivers, [integer()])
  end

  def new, do: %__MODULE__{}

  def merge(a = %__MODULE__{}, b = %__MODULE__{}) do
    MapUtils.patch_ignore_nil(a, b)
  end
end
