defmodule F1Bot.F1Session.RaceControl.Message do
  @moduledoc ""
  use TypedStruct

  typedstruct do
    @typedoc "Race Control Message"

    field(:source, String.t())
    field(:message, String.t())
    field(:flag, atom())
    field(:mentions, list())
  end

  def new do
    %__MODULE__{}
  end
end
