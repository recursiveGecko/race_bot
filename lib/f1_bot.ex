defmodule F1Bot do
  @moduledoc """
  API for retrieving data between different system components.
  """

  require Logger
  alias F1Bot.F1Session.LiveTimingHandlers.ProcessingOptions
  alias F1Bot.Replay

  @doc """
  Gets a configuration value for `F1Bot` application.
  """
  def get_env(key, default \\ nil) when is_atom(key) do
    Application.get_env(:f1_bot, key, default)
  end

  @doc """
  Same as `get_env/2` but returns an ok tuple or :error.
  """
  def fetch_env(key) when is_atom(key) do
    Application.fetch_env(:f1_bot, key)
  end

  @doc """
  Returns configured demo mode URL or nil if not configured.
  """
  def demo_mode_url() do
    F1Bot.get_env(:demo_mode_url)
  end

  @doc """
  Returns true if demo mode is enabled.
  """
  def demo_mode?() do
    F1Bot.demo_mode_url() != nil
  end

  @doc """
  Returns the list of drivers in the current session.
  """
  def driver_list() do
    F1Bot.F1Session.Server.driver_list()
  end

  @doc """
  Returns the race summary of the driver with the given number which
  contains the driver's stints, top speed, best and average lap times,
  and best and average sector times.
  """
  def driver_summary(driver_no) do
    F1Bot.F1Session.Server.driver_summary(driver_no)
  end

  @doc """
  Returns information about the driver with the given number such as
  their name, picture URL, team, and team color.
  """
  def driver_info_by_number(driver_number) when is_integer(driver_number) do
    F1Bot.F1Session.Server.driver_info_by_number(driver_number)
  end

  @doc """
  Same as `driver_info_by_number/1` but takes the driver's 3-letter abbreviation
  """
  def driver_info_by_abbr(driver_abbr) do
    F1Bot.F1Session.Server.driver_info_by_abbr(driver_abbr)
  end

  @doc """
  Returns full session data from the `DriverDataRepo` for the driver with the given number.
  Contains all laps, stints and other data collected about the driver in this session.
  """
  def driver_session_data(driver_number) when is_integer(driver_number) do
    F1Bot.F1Session.Server.driver_session_data(driver_number)
  end

  @doc """
  Returns the best lap time, best sector times, and top speed in this session.
  """
  def session_best_stats() do
    F1Bot.F1Session.Server.session_best_stats()
  end

  @doc """
  Returns a copy of the current `F1Session` session state for analysis.

  `light_copy` controls whether "heavy" data, such as position and car telemetry data
  are stripped from the copy to reduce its size.
  """
  def session_copy(light_copy \\ true) do
    F1Bot.F1Session.Server.state(light_copy)
  end

  @doc """
  Returns information about the session such as the session type (FP/Q/R) and name.
  """
  def session_info() do
    F1Bot.F1Session.Server.session_info()
  end

  @doc """
  Returns the current session status (e.g. started, in progress, ended)
  """
  def session_status() do
    F1Bot.F1Session.Server.session_status()
  end

  @doc """
  Returns a history of track status changes (safety cars, red flags, etc.)
  """
  def track_status_history() do
    F1Bot.F1Session.Server.track_status_history()
  end

  @doc """
  Returns the current session clock - time remaining in qualifying and FP sessions
  or time left on the 2h timer during races.
  """
  def session_clock() do
    F1Bot.F1Session.Server.session_clock_from_local_time(Timex.now())
  end

  @doc """
  Emits all known events from the current session state to the event bus
  to (1) update the delayed events caches (which are used on the website)
  and (2) synchronize the state of all connected Phoenix clients.
  This includes events such as session information, driver list,
  and session summaries for all drivers.

  This should rarely (if ever) be needed as relevant events are automatically
  emitted on changes, which should keep the states synchronized at all times.

  See `F1Bot.F1Session.EventGenerator.StateSync` for more details.
  """
  def resync_state_events() do
    F1Bot.F1Session.Server.resync_state_events()
  end

  @doc """
  Resets the session state and clears all caches
  """
  def reset_session() do
    F1Bot.F1Session.Server.reset_session()
  end

  @doc """
  Fetches session archives from a given URL, silently replays them, and
  replaces the current session with the replayed session.
  Useful for testing and restoring data from the last session on server
  restart.
  """
  def reload_session(light_data) when is_boolean(light_data) do
    reload_session(nil, ProcessingOptions.new(), light_data)
  end

  def reload_session(url, light_data) when is_binary(url) and is_boolean(light_data) do
    reload_session(url, ProcessingOptions.new(), light_data)
  end

  def reload_session(processing_opts, light_data)
      when is_struct(processing_opts, ProcessingOptions) and is_boolean(light_data) do
    reload_session(nil, processing_opts, light_data)
  end

  def reload_session(url, processing_opts, light_data)
      when is_struct(processing_opts, ProcessingOptions) and is_boolean(light_data) do
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

    replay_options = %Replay.Options{
      exclude_files_regex: exclude_files_regex,
      report_progress: true,
      processing_options: processing_opts
    }

    with {_, status} when status in [:ends, :finalised, :not_available] <- session_status(),
         {:ok, url} <- url_result,
         {:ok, %{session: session}} <- Replay.start_replay(url, replay_options) do
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

  @doc """
  Same as `reload_session/2`, but it replays the archives in real time,
  as if the session was currently in progress (equivalent to demo mode).
  Useful for development.
  """
  def replay_session_realtime(url) do
    Replay.Server.start_replay(url)
  end

  @doc """
  Stops the session replay started with `replay_session_realtime/1`.
  """
  def stop_session_replay() do
    Replay.Server.stop_replay()
  end

  @doc """
  Fast-forwards the session replay started with `replay_session_realtime/1`
  by a given number of seconds.
  """
  def fast_forward_replay(seconds) do
    Replay.Server.fast_forward(seconds)
  end

  @doc """
  Returns the current lap number.
  """
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

  @doc """
  Returns an ok-wrapped boolean indicating whether the current session
  is a race or another type of session (FP/Q).
  Returns an error if the session info is not available.
  """
  def is_race?() do
    case session_info() do
      {:ok, info} ->
        is_race = F1Bot.F1Session.SessionInfo.is_race?(info)
        {:ok, is_race}

      {:error, err} ->
        {:error, err}
    end
  end

  @doc """
  Downloads all available session archives and caches them locally.
  You shouldn't need to call this function directly, as the archives are cached
  automatically when they are first accessed.
  """
  def sync_archive_cache(recheck_index \\ false) do
    F1Bot.ExternalApi.F1LiveTiming.download_all_archives([], recheck_index)
  end
end
