defmodule F1Bot do
  @moduledoc """
  API for retrieving data between different system components.
  """

  require Logger

  def get_env(key, default \\ nil) when is_atom(key) do
    Application.get_env(:f1_bot, key, default)
  end

  def fetch_env(key) when is_atom(key) do
    Application.fetch_env(:f1_bot, key)
  end

  def driver_info(driver_number) when is_integer(driver_number) do
    F1Bot.F1Session.driver_info(driver_number)
  end

  def driver_info_by_abbr(driver_abbr) do
    F1Bot.F1Session.driver_info_by_abbr(driver_abbr)
  end

  def driver_stats(driver_number) when is_integer(driver_number) do
    F1Bot.F1Session.driver_session_data(driver_number)
  end

  def session_info() do
    F1Bot.F1Session.session_info()
  end

  def session_status() do
    F1Bot.F1Session.session_status()
  end

  def lap_number() do
    {:ok, info} = session_info()

    case info.lap_number do
      nil -> {:error, :no_laps}
      x -> {:ok, x}
    end
  end

  def api_base() do
    case session_info() do
      {:ok, %{www_path: www_path}} -> {:ok, www_path}
      {:error, _} -> {:error, :no_session_info}
    end
  end

  def is_race?() do
    {:ok, info} = session_info()
    F1Bot.F1Session.SessionInfo.is_race?(info)
  end
end
