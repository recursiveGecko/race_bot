defmodule F1Bot.F1Session.LiveTimingHandlers.ProcessingResult do
  use TypedStruct

  typedstruct do
    field :session, F1Session.t(), enforce: true
    field :events, [Event.t()], enforce: true
    field :reset_session, boolean(), default: false
  end
end
