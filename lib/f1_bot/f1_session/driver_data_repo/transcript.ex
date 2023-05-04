defmodule F1Bot.F1Session.DriverDataRepo.Transcript do
  use Ecto.Schema
  import Ecto.Changeset
  alias F1Bot.F1Session.Common.Event

  @primary_key false

  embedded_schema do
    field :driver_number, :integer
    field :length_sec, :float
    field :utc_date, :utc_datetime
    field :message, :string
  end

  def validate(params) do
    %__MODULE__{}
    |> cast(params, [:driver_number, :utc_date, :message, :length_sec])
    |> validate_required([:driver_number, :utc_date, :message, :length_sec])
    |> apply_action(:validate)
  end

  def to_event(this = %__MODULE__{}) do
    ts = DateTime.to_unix(this.utc_date, :millisecond)
    Event.new("driver:transcript", %{transcript: this}, ts)
  end
end
