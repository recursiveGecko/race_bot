defmodule F1Bot.F1Session.DriverDataRepo.Stints do
  @moduledoc """
  Stores all information about driver's stints in the current session,
  e.g. tyre compount and tyre age.
  """
  use TypedStruct

  defmodule Stint do
    @moduledoc """
    Holds information about a single stint.
    """
    use TypedStruct

    typedstruct do
      @typedoc "Stint information"

      field(:number, pos_integer(), enforce: true)
      field(:compound, atom(), enforce: true)
      field(:age, non_neg_integer(), enforce: true)
      field(:tyres_changed, boolean(), enforce: true)
    end

    def new(stint_data) do
      struct!(Stint, stint_data)
    end

    def update(self = %__MODULE__{}, stint_data) do
      new_self = struct!(self, stint_data)
      has_changes = new_self != self
      {has_changes, new_self}
    end
  end

  typedstruct do
    field(:data, [Stint.t()], default: [])
  end

  def new() do
    %__MODULE__{}
  end

  def push_stint_data(self = %__MODULE__{}, stint_data) do
    stint_number = stint_data.number

    {update_type, new_data} =
      self.data
      |> Enum.reduce({nil, []}, fn
        # Handle case where this is the first stint with matching number to be updated
        stint = %{number: ^stint_number}, {update_type, new_data} when update_type == nil ->
          {has_changes, stint} = Stint.update(stint, stint_data)
          update_type = if has_changes, do: :has_changes, else: :no_changes
          {update_type, [stint | new_data]}

        # Handle case where stint number doesn't match OR one of the stints has already been updated
        stint, {update_type, new_data} ->
          {update_type, [stint | new_data]}
      end)

    case update_type do
      :has_changes ->
        change_type =
          case current_stint_number?(self, stint_number) do
            true -> :updated_current
            false -> :updated_old
          end

        new_data = Enum.reverse(new_data)
        self = %{self | data: new_data}

        {change_type, self}

      :no_changes ->
        {:no_changes, self}

      nil ->
        stint = Stint.new(stint_data)
        self = %{self | data: [stint | self.data]}
        {:new, self}
    end
  end

  def current_stint_number?(self = %__MODULE__{}, stint_number) do
    case last_stint(self) do
      {:ok, stint} -> stint.number == stint_number
      _ -> false
    end
  end

  def last_stint(_self = %__MODULE__{data: [last | _rest]}), do: {:ok, last}
  def last_stint(_self = %__MODULE__{data: []}), do: {:error, :no_data}

  def find_stint(self = %__MODULE__{}, stint_number) do
    case Enum.find(self.data, fn x -> x.number == stint_number end) do
      nil -> {:error, :not_found}
      stint -> {:ok, stint}
    end
  end
end
