defmodule F1Bot.Replay.Options do
  @moduledoc """
    All options are optional unless otherwise noted.

    * `:report_progress` - If true, logs processing progress to the console.

    * `:exclude_files_regex` - A regex that excludes matching `.jsonStream`
    files from the download and replay, e.g. to exclude bulky `*.z.jsonStream` files
    when they are not needed.

    * `:replay_while_fn` - a 3-arity function that receives the current replay state,
    current packet and its timestamp in milliseconds.
    This function is called *before* the packet is processed. If the function
    returns false, the packet is left unprocessed (kept), replay is paused and `start_replay/2`
    will return the current replay state.
    Replay can by resumed by calling `replay_dataset/2` with the returned state and new
    options (e.g. different `replay_while_fn/3`).

    * `:packets_fn` - a 3-arity function that receives the current replay state,
    current packet and its timestamp in milliseconds.
    This function is called for every packet and can be used to implement custom packet
    processing logic (e.g. to simply print all received packets to console).
    By default this function will process the packet using
    `LiveTimingHandlers.process_live_timing_packet/3` and store the resulting `F1Session`
    state in the replay state.

    * `:events_fn` - a 1-arity function that will receive a list of events produced by **default**
    `:packets_fn` implementation. This option has no effect when `:packets_fn` is overriden.
    By default `:events_fn` is unspecified, but `Mix.Tasks.Backtest` for example overrides
    it to broadcast events on the PubSub bus. See module docs for more details.
  """
  use TypedStruct
  alias F1Bot.F1Session.LiveTimingHandlers.ProcessingOptions

  typedstruct do
    field(:report_progress, boolean())
    field(:exclude_files_regex, Regex.t())
    field(:replay_while_fn, function())
    field(:packets_fn, function())
    field(:events_fn, function())
    field(:processing_options, ProcessingOptions.t(), default: ProcessingOptions.new())
  end
end
