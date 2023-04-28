defmodule F1Bot.F1Session.DriverDataRepo.Transcripts do
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo.Transcript
  alias F1Bot.F1Session.Common.Event

  typedstruct do
    field :driver_number, pos_integer()
    field :transcripts, [Transcript.t()], default: []
  end

  def new(driver_number) when is_integer(driver_number) do
    %__MODULE__{
      driver_number: driver_number
    }
  end

  def append(this = %__MODULE__{}, transcript = %Transcript{}) do
    %{this | transcripts: [transcript | this.transcripts]}
  end

  def to_init_event(this) do
    Event.new("driver_transcripts_init:#{this.driver_number}", %{transcripts: this.transcripts})
  end
end
