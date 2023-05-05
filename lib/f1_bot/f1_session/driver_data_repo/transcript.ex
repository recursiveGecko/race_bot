defmodule F1Bot.F1Session.DriverDataRepo.Transcript do
  use Ecto.Schema
  import Ecto.Changeset
  alias F1Bot.F1Session.Common.Event

  @derive Jason.Encoder
  @primary_key false

  embedded_schema do
    field(:driver_number, :integer)
    field(:duration_sec, :float)
    field(:utc_date, :utc_datetime)
    field(:estimated_real_date, :utc_datetime)
    field(:playhead_utc_date, :utc_datetime)
    field(:message, :string)
  end

  def validate(params) do
    %__MODULE__{}
    |> cast(params, [
      :driver_number,
      :utc_date,
      :playhead_utc_date,
      :estimated_real_date,
      :message,
      :duration_sec
    ])
    |> validate_required([
      :driver_number,
      :utc_date,
      :message,
      :duration_sec
    ])
    |> apply_action(:validate)
  end

  def to_event(this = %__MODULE__{}) do
    date =
      if this.estimated_real_date != nil do
        this.estimated_real_date
      else
        recording_date = this.utc_date || this.playhead_utc_date || DateTime.utc_now()
        DateTime.add(recording_date, -20, :second)
      end

    ts = DateTime.to_unix(date, :millisecond)
    Event.new("driver:transcript", %{transcript: this}, ts)
  end
end
