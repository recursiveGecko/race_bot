defmodule F1Bot.F1Session.DriverCache do
  @moduledoc """
  Stores and handles changes to personal driver information.
  """
  use TypedStruct

  alias F1Bot.F1Session.Common.Event
  alias F1Bot.F1Session.DriverCache.DriverInfo

  typedstruct do
    @typedoc "Cache of drivers' personal details"

    field(:drivers, map(), default: %{})
  end

  def new() do
    %__MODULE__{}
  end

  def driver_list(%__MODULE__{drivers: drivers}) do
    driver_list =
      drivers
      |> Map.values()
      |> Enum.sort_by(&(&1.last_name || &1.driver_abbr || &1.short_name || &1.full_name))

    {:ok, driver_list}
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

  def to_event(driver_cache = %__MODULE__{}) do
    {:ok, driver_list} = driver_list(driver_cache)
    Event.new("driver:list", driver_list)
  end

  def process_updates(driver_cache, partial_drivers) when is_list(partial_drivers) do
    new_driver_cache =
      Enum.reduce(partial_drivers, driver_cache, fn driver, driver_cache ->
        process_update(driver_cache, driver)
      end)
      |> assign_chart_team_order()
      |> assign_chart_order()

    events =
      if new_driver_cache != driver_cache do
        [to_event(new_driver_cache)]
      else
        []
      end

    {new_driver_cache, events}
  end

  defp process_update(
         driver_cache = %__MODULE__{},
         partial_driver = %DriverInfo{driver_number: driver_number}
       )
       when driver_number != nil do
    old_driver =
      case get_driver_by_number(driver_cache, driver_number) do
        {:ok, d} -> d
        _ -> %DriverInfo{}
      end

    merged_driver = MapUtils.patch_ignore_nil(old_driver, partial_driver)
    put_driver(driver_cache, merged_driver)
  end

  defp process_update(
         _driver_cache = %__MODULE__{},
         _partial_driver
       ) do
    {:error, :invalid_driver}
  end

  defp assign_chart_order(self = %__MODULE__{}) do
    driver_map =
      self.drivers
      |> Map.values()
      |> Enum.sort_by(&"#{&1.team_name}-#{&1.chart_team_order}", :asc)
      |> Enum.with_index(0)
      |> Enum.map(fn {driver, index} ->
        driver = %{driver | chart_order: index}
        {driver.driver_number, driver}
      end)
      |> Enum.into(%{})

    %{self | drivers: driver_map}
  end

  defp assign_chart_team_order(self = %__MODULE__{}) do
    grouped =
      self.drivers
      |> Map.values()
      |> Enum.group_by(fn driver -> "#{driver.team_name}##{driver.team_color}" end)

    modified =
      for {_team, drivers} <- grouped do
        drivers
        |> Enum.sort_by(& &1.driver_number, :asc)
        |> Enum.with_index(0)
        |> Enum.map(fn {driver, index} ->
          driver = %{driver | chart_team_order: index}
          {driver.driver_number, driver}
        end)
      end

    driver_map =
      modified
      |> List.flatten()
      |> Enum.into(%{})

    %{self | drivers: driver_map}
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
end
