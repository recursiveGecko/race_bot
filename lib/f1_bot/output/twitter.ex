defmodule F1Bot.Output.Twitter do
  @moduledoc """
  Listens for events published by `F1Bot.F1Session.Server`, composes messages for Twitter
  and calls a configured Twitter client (live or console) to send them.
  """
  use GenServer
  require Logger

  alias F1Bot.Output.Common
  alias F1Bot.DelayedEvents
  alias F1Bot.DataTransform.Format
  alias F1Bot.F1Session.DriverDataRepo.Transcript

  @common_hashtags "#f1"

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: server_via())
  end

  @impl true
  def init(_init_arg) do
    {:ok, _topics} =
      DelayedEvents.subscribe_with_delay(
        [
          "aggregate_stats:fastest_lap",
          "aggregate_stats:fastest_sector",
          "aggregate_stats:top_speed",
          "driver:tyre_change",
          "driver:transcript",
          "session_status:started",
          "race_control:message"
        ],
        25_000,
        false
      )

    state = %{}

    {:ok, state}
  end

  @impl true
  def handle_info(
        e = %{
          scope: "aggregate_stats:fastest_lap",
          payload: %{
            driver_number: driver_number,
            lap_time: lap_time,
            lap_delta: lap_delta,
            type: overall_or_personal
          }
        },
        state
      ) do
    if Common.should_post_stats(e) do
      driver = Common.get_driver_name_by_number(e, driver_number)

      lap_time = Format.format_lap_time(lap_time)
      lap_delta = Format.format_lap_delta(lap_delta)

      type =
        case overall_or_personal do
          :overall -> "the fastest lap"
          :personal -> "a personal fastest lap"
        end

      type_hashtag =
        case overall_or_personal do
          :overall -> "#FastestLap #PersonalFastestLap"
          :personal -> "#PersonalFastestLap"
        end

      msg =
        """
        #{driver} just set #{type} of #{lap_time} (Δ #{lap_delta})
        #{type_hashtag} ##{Common.get_driver_abbr_by_number(e, driver_number)} #{@common_hashtags} #{ts_hashtag()}
        """
        |> String.trim()

      F1Bot.ExternalApi.Twitter.post_tweet(msg)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        e = %{
          scope: "aggregate_stats:fastest_sector",
          payload: %{
            driver_number: driver_number,
            sector: sector,
            sector_time: sector_time,
            sector_delta: sector_delta,
            type: fastest_type
          }
        },
        state
      )
      when sector_delta != nil do
    if Common.should_post_stats(e) and fastest_type == :overall do
      driver = Common.get_driver_name_by_number(e, driver_number)

      sector_time = Format.format_lap_time(sector_time)
      sector_delta = Format.format_lap_delta(sector_delta)

      msg =
        """
        #{driver} just set the fastest sector #{sector} of #{sector_time} (Δ #{sector_delta})
        #FastestSector ##{Common.get_driver_abbr_by_number(e, driver_number)} #{@common_hashtags} #{ts_hashtag()}
        """
        |> String.trim()

      F1Bot.ExternalApi.Twitter.post_tweet(msg)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        e = %{
          scope: "aggregate_stats:top_speed",
          payload: %{
            driver_number: driver_number,
            speed: speed,
            speed_delta: speed_delta,
            type: overall_or_personal
          }
        },
        state
      ) do
    if overall_or_personal == :overall do
      driver = Common.get_driver_name_by_number(e, driver_number)

      type =
        case overall_or_personal do
          :overall -> "an overall top speed"
          :personal -> "personal top speed"
        end

      msg =
        """
        #{driver} reached #{type} of #{speed} km/h (Δ +#{speed_delta} km/h) at some point in the previous lap.
        #TopSpeed ##{Common.get_driver_abbr_by_number(e, driver_number)} #{@common_hashtags} #{ts_hashtag()}
        """
        |> String.trim()

      F1Bot.ExternalApi.Twitter.post_tweet(msg)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        e = %{
          scope: "driver:tyre_change",
          payload: %{
            driver_number: driver_number,
            is_correction: is_correction,
            compound: compound,
            age: age
          },
          meta: %{
            session_status: session_status
          }
        },
        state
      ) do
    if session_status == :started and not is_correction do
      driver = Common.get_driver_name_by_number(e, driver_number)

      age_str =
        if age == 0 do
          "new"
        else
          "#{age} laps old"
        end

      msg =
        """
        #{driver} pitted for #{age_str} #{compound} tyres.
        #PitStop ##{Common.get_driver_abbr_by_number(e, driver_number)} #{@common_hashtags} #{ts_hashtag()}
        """
        |> String.trim()

      F1Bot.ExternalApi.Twitter.post_tweet(msg)
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        e = %{
          scope: "driver:transcript",
          payload: %{
            transcript: %Transcript{
              driver_number: driver_number,
              message: transcript_msg
            }
          }
        },
        state
      ) do
    driver = Common.get_driver_name_by_number(e, driver_number)

    _msg =
      """
      🎙️ #{driver} radio (AI): #{transcript_msg}

      Note: Experimental and often wrong. Reach out if you think you could help.
      #Radio ##{Common.get_driver_abbr_by_number(e, driver_number)} #{@common_hashtags} #{ts_hashtag()}
      """
      |> String.trim()

    # TODO: Temporarily disabled due to low Twitter rate limits
    # F1Bot.ExternalApi.Twitter.post_tweet(msg)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        %{
          scope: "session_status:started",
          payload: %{
            gp_name: gp_name,
            session_type: session_type
          }
        },
        state
      ) do
    session_name = "#{gp_name} - #{session_type}"

    msg =
      """
      #{session_name} just started!
      #SessionStarted #{@common_hashtags} #{ts_hashtag()}
      """
      |> String.trim()

    F1Bot.ExternalApi.Twitter.post_tweet(msg)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        %{
          scope: "race_control:message",
          payload: %{
            # flag: flag,
            message: message,
            mentions: mentions,
            source: source
          }
        },
        state
      ) do
    driver_hashtags =
      for abbr <- mentions do
        "##{abbr}"
      end
      |> Enum.join(" ")

    source_prefix =
      case source do
        :stewards -> "FIA Stewards"
        :stewards_correction -> "FIA Stewards correction"
        _ -> "Race Control"
      end

    source_hashtag =
      case source do
        :stewards -> "#FIAStewards"
        :stewards_correction -> "#FIAStewards"
        _ -> "#RaceControl"
      end

    msg =
      """
      #{source_prefix}: #{message}
      #{source_hashtag} #{driver_hashtags} #{@common_hashtags} #{ts_hashtag()}
      """
      |> String.trim()

    F1Bot.ExternalApi.Twitter.post_tweet(msg)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.info("Ignored output message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp ts_hashtag do
    {:ok, ts} = Timex.now() |> Timex.format("{0h24}{0m}{0s}")
    "#T#{ts}"
  end

  defp server_via() do
    __MODULE__
  end
end
