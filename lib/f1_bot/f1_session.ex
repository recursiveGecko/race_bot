defmodule F1Bot.F1Session do
  @moduledoc """
  Public API for a running `F1Bot.F1Session.Server` that holds the live `F1Bot.F1Session.Impl` instance.
  """
  alias F1Bot.F1Session

  def session_info() do
    call_genserver({:get_session_info})
  end

  def session_status() do
    call_genserver({:get_session_status})
  end

  def driver_session_data(driver_number) when is_integer(driver_number) do
    call_genserver({:get_driver_session_data, driver_number})
  end

  def driver_info(driver_number) when is_integer(driver_number) do
    call_genserver({:get_driver_info, driver_number})
  end

  def driver_info_by_abbr(driver_abbr) do
    call_genserver({:get_driver_info_by_abbr, driver_abbr})
  end

  def push_driver_list_update(drivers) do
    call_genserver({:push_driver_list_update, drivers})
  end

  def push_telemetry(driver_number, channels) when is_integer(driver_number) do
    call_genserver({:push_telemetry, driver_number, channels})
  end

  def push_position(driver_number, position) when is_integer(driver_number) do
    call_genserver({:push_position, driver_number, position})
  end

  def push_lap_time(driver_number, lap_time, timestamp) when is_integer(driver_number) do
    call_genserver({:push_lap_time, driver_number, lap_time, timestamp})
  end

  def push_sector_time(driver_number, sector, sector_time, timestamp)
      when is_integer(driver_number) do
    call_genserver({:push_sector_time, driver_number, sector, sector_time, timestamp})
  end

  def push_lap_number(driver_number, lap_number, timestamp) when is_integer(driver_number) do
    call_genserver({:push_lap_number, driver_number, lap_number, timestamp})
  end

  def push_race_control_messages(messages) do
    call_genserver({:push_race_control_messages, messages})
  end

  def push_session_info(session_info) do
    call_genserver({:push_session_info, session_info})
  end

  def push_session_status(session_status) do
    call_genserver({:push_session_status, session_status})
  end

  def push_stint_data(driver_number, stint_data) when is_integer(driver_number) do
    call_genserver({:push_stint_data, driver_number, stint_data})
  end

  defp call_genserver(request) do
    F1Session.Server.server_via()
    |> GenServer.call(request)
  end
end
