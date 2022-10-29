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

  def demo_mode_url() do
    F1Bot.get_env(:demo_mode_url)
  end

  def driver_list() do
    F1Bot.F1Session.Server.driver_list()
  end

  def driver_summary(driver_no) do
    F1Bot.F1Session.Server.driver_summary(driver_no)
  end

  def driver_info_by_number(driver_number) when is_integer(driver_number) do
    F1Bot.F1Session.Server.driver_info_by_number(driver_number)
  end

  def driver_info_by_abbr(driver_abbr) do
    F1Bot.F1Session.Server.driver_info_by_abbr(driver_abbr)
  end

  def driver_session_data(driver_number) when is_integer(driver_number) do
    F1Bot.F1Session.Server.driver_session_data(driver_number)
  end

  def session_best_stats() do
    F1Bot.F1Session.Server.session_best_stats()
  end

  def session_copy(light_copy \\ true) do
    F1Bot.F1Session.Server.state(light_copy)
  end

  def session_info() do
    F1Bot.F1Session.Server.session_info()
  end

  def session_status() do
    F1Bot.F1Session.Server.session_status()
  end

  def track_status_history() do
    F1Bot.F1Session.Server.track_status_history()
  end

  def session_clock() do
    F1Bot.F1Session.Server.session_clock_from_local_time(Timex.now())
  end

  def reload_live_data(url \\ nil, light_data) when is_boolean(light_data) do
    url_result =
      if url == nil do
        F1Bot.ExternalApi.F1LiveTiming.current_archive_url_if_completed()
      else
        {:ok, url}
      end

    exclude_files_regex =
      if light_data do
        ~r/\.z\./
      else
        nil
      end

    replay_options = %{
      exclude_files_regex: exclude_files_regex,
      report_progress: true
    }

    with {_, status} when status in [:ends, :finalised, :not_available] <- session_status(),
         {:ok, url} <- url_result,
         {:ok, %{session: session}} <- F1Bot.Replay.start_replay(url, replay_options) do
      F1Bot.F1Session.Server.replace_session(session)
    else
      {:ok, session_status} ->
        Logger.error("Unable to reload data, session status is #{inspect(session_status)}")
        {:error, :invalid_session_status}

      {:error, err} ->
        Logger.error("Unable to reload data, error: #{inspect(err)}")
        {:error, err}
    end
  end

  def lap_number() do
    case session_info() do
      {:ok, info} ->
        case info.lap_number do
          nil -> {:error, :no_laps}
          x -> {:ok, x}
        end

      {:error, err} ->
        {:error, err}
    end
  end

  def is_race?() do
    case session_info() do
      {:ok, info} ->
        is_race = F1Bot.F1Session.SessionInfo.is_race?(info)
        {:ok, is_race}

      {:error, err} ->
        {:error, err}
    end
  end
end
