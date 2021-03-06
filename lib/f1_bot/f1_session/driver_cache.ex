defmodule F1Bot.F1Session.DriverCache do
  @moduledoc """
  Stores and handles changes to personal driver information.
  """
  use TypedStruct

  alias F1Bot.F1Session.DriverCache.DriverInfo

  typedstruct do
    @typedoc "Cache of drivers' personal details"

    field(:drivers, map(), default: %{})
  end

  def new() do
    %__MODULE__{}
  end

  def get_driver_by_number(%__MODULE__{drivers: drivers}, driver_number) do
    case Map.fetch(drivers, driver_number) do
      {:ok, val} -> {:ok, val}
      :error -> {:error, :not_found}
    end
  end

  def get_driver_by_abbr(%__MODULE__{drivers: drivers}, abbr) do
    abbr = abbr |> String.trim() |> String.upcase()

    result =
      Map.values(drivers)
      |> Enum.find(fn drv -> drv.driver_abbr == abbr end)

    case result do
      nil -> {:error, :not_found}
      val -> {:ok, val}
    end
  end

  def put_driver(
        driver_cache = %__MODULE__{drivers: drivers},
        driver_info = %DriverInfo{driver_number: driver_number}
      )
      when driver_number != nil do
    new_cache = Map.put(drivers, driver_number, driver_info)
    driver_cache = %{driver_cache | drivers: new_cache}

    driver_cache
  end

  def process_update(
        driver_cache = %__MODULE__{},
        partial_driver = %DriverInfo{driver_number: driver_number}
      )
      when driver_number != nil do
    old_driver =
      case get_driver_by_number(driver_cache, driver_number) do
        {:ok, d} -> d
        _ -> %{}
      end

    merged_driver = DriverInfo.merge(old_driver, partial_driver)
    put_driver(driver_cache, merged_driver)
  end

  def process_update(
        _driver_cache = %__MODULE__{},
        _partial_driver
      ) do
    {:error, :invalid_driver}
  end
end
