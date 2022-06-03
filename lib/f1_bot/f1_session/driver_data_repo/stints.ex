defmodule F1Bot.F1Session.DriverDataRepo.Stints do
  @moduledoc """
  Stores all information about driver's stints in the current session,
  e.g. tyre compount and tyre age.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverDataRepo.Stint

  typedstruct do
    field(:data, [Stint.t()], default: [])
  end

  def new() do
    %__MODULE__{}
  end

  def push_stint_data(self = %__MODULE__{}, stint_data, current_lap_number) do
    stint_number = stint_data.number

    {update_type, new_data} =
      self.data
      |> Enum.reduce({nil, []}, fn
        # Handle case where this is the first stint with matching number to be updated
        stint = %{number: ^stint_number}, {update_type, new_data} when update_type == nil ->
          {update_type, stint} = Stint.update(stint, stint_data)
          {update_type, [stint | new_data]}

        # Handle case where stint number doesn't match OR one of the stints has already been updated
        stint, {update_type, new_data} ->
          {update_type, [stint | new_data]}
      end)

    cond do
      update_type == :changed_compound ->
        change_type =
          case current_stint_number?(self, stint_number) do
            true -> :updated_current_compound
            false -> :updated_old_compound
          end

        new_data =
          new_data
          |> fix_lap_numbers()
          |> sort_by_number(:desc)

        self = %{self | data: new_data}

        {change_type, self}

      update_type in [:other_fields, :no_changes] ->
        new_data =
          new_data
          |> fix_lap_numbers()
          |> sort_by_number(:desc)

        self = %{self | data: new_data}
        {update_type, self}

      update_type == nil ->
        stint_data = Map.put(stint_data, :lap_number, current_lap_number)
        stint = Stint.new(stint_data)

        new_data =
          [stint | self.data]
          |> fix_lap_numbers()
          |> sort_by_number(:desc)

        self = %{self | data: new_data}
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

  def sort_by_number(stints, direction \\ :asc) do
    Enum.sort_by(stints, fn s -> s.number end, direction)
  end

  # See Monaco 2022 integration tests to see why this is necessary
  def fix_lap_numbers(stints) do
    stints
    |> sort_by_number(:asc)
    |> fix_lap_numbers([])
  end

  defp fix_lap_numbers(_stints = [first, second | rest], acc) do
    first_laps = Stint.count_laps(first)

    second_lap_number =
      cond do
        first_laps == nil ->
          second.lap_number

        first.lap_number == nil ->
          second.lap_number

        true ->
          first.lap_number + first_laps
      end

    second = %{second | lap_number: second_lap_number}

    fix_lap_numbers([second | rest], [first | acc])
  end

  defp fix_lap_numbers(_stints = [first | rest], acc) do
    fix_lap_numbers(rest, [first | acc])
  end

  defp fix_lap_numbers(_stints = [], acc) do
    Enum.reverse(acc)
  end
end
