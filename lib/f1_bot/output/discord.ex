defmodule F1Bot.Output.Discord do
  @moduledoc """
  Listens for events published by `F1Bot.F1Session.Server`, composes messages for Discord
  and calls a configured Discord client (live or console) to send them.
  """
  use GenServer
  require Logger

  alias F1Bot.Output.Common
  alias F1Bot.PubSub
  alias F1Bot.DataTransform.Format
  alias F1Bot.F1Session.DriverDataRepo.Transcript

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: server_via())
  end

  @impl true
  def init(_init_arg) do
    PubSub.subscribe_to_event("aggregate_stats:fastest_lap")
    PubSub.subscribe_to_event("aggregate_stats:fastest_sector")
    PubSub.subscribe_to_event("aggregate_stats:top_speed")
    PubSub.subscribe_to_event("driver:tyre_change")
    PubSub.subscribe_to_event("driver:transcript")
    PubSub.subscribe_to_event("session_status:started")
    PubSub.subscribe_to_event("race_control:message")

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
    if Common.should_post_stats(e) and overall_or_personal == :overall do
      driver = Common.get_driver_name_by_number(e, driver_number)

      lap_time = Format.format_lap_time(lap_time)
      lap_delta = Format.format_lap_delta(lap_delta)

      emoji =
        case overall_or_personal do
          :overall -> F1Bot.ExternalApi.Discord.get_emoji_or_default(:quick, ":zap:")
          :personal -> F1Bot.ExternalApi.Discord.get_emoji_or_default(:timer, ":comet:")
        end

      type =
        case overall_or_personal do
          :overall -> "#{emoji}  **Fastest Lap**"
          :personal -> "#{emoji}  **Personal Fastest Lap**"
        end

      msg = "#{type}: `#{driver}` of `#{lap_time}` `(#{lap_delta})`"

      F1Bot.ExternalApi.Discord.post_message(msg)
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

      emoji = F1Bot.ExternalApi.Discord.get_emoji_or_default(:quick, ":zap:")
      type = "#{emoji}  **Fastest Sector #{sector}**"

      msg = "#{type}: `#{driver}` of `#{sector_time}` `(#{sector_delta})`"

      F1Bot.ExternalApi.Discord.post_message(msg)
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

      emoji =
        case overall_or_personal do
          :overall -> F1Bot.ExternalApi.Discord.get_emoji_or_default(:quick, ":zap:")
          :personal -> F1Bot.ExternalApi.Discord.get_emoji_or_default(:speedometer, ":comet:")
        end

      type =
        case overall_or_personal do
          :overall -> "#{emoji}  **Overall Top Speed**"
          :personal -> "#{emoji}  **Personal Top Speed**"
        end

      msg = "#{type}: `#{driver}` of `#{speed} km/h` `(+#{speed_delta} km/h)`"
      F1Bot.ExternalApi.Discord.post_message(msg)
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
          session_status: session_status
        },
        state
      ) do
    if session_status == :started do
      driver = Common.get_driver_name_by_number(e, driver_number)

      age_str =
        if age == 0 do
          "New"
        else
          "#{age} laps old"
        end

      correction =
        if is_correction do
          " (correction)"
        end

      emoji =
        "#{compound}_tyre"
        |> String.to_atom()
        |> F1Bot.ExternalApi.Discord.get_emoji_or_default(":arrows_counterclockwise:")

      msg = "#{emoji}  **Pit Stop#{correction}**: `#{driver}` for `#{compound}` tyres (`#{age_str}`)"

      F1Bot.ExternalApi.Discord.post_message(msg)
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
          },
        },
        state
      ) do
    driver = Common.get_driver_name_by_number(e, driver_number)
    emoji = ":studio_microphone:"
    disclaimer = "***Note:** Transcripts are AI-generated, experimental, and often wrong. Reach out to recursiveGecko if you think you could help us improve.*"
    msg = "#{emoji}  `#{driver}` radio: #{transcript_msg}\n#{disclaimer}"

    F1Bot.ExternalApi.Discord.post_message(msg)

    {:noreply, state}
  end

  @impl true
  def handle_info(
        _e = %{
          scope: "session_status:started",
          payload: %{
            gp_name: gp_name,
            session_type: session_type
          }
        },
        state
      ) do
    session_name = "#{gp_name} - #{session_type}"

    F1Bot.ExternalApi.Discord.post_message(
      ":traffic_light: **#{session_name} just started** :traffic_light:"
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(
        _e = %{
          scope: "race_control:message",
          payload: %{
            flag: flag,
            message: message,
            source: source
          }
        },
        state
      ) do
    emoji =
      case flag do
        :yellow -> :flag_yellow
        :red -> :flag_red
        :chequered -> :flag_chequered
        _ -> :announcement
      end
      |> F1Bot.ExternalApi.Discord.get_emoji_or_default(":information_source:")

    source_prefix =
      cond do
        source == :stewards -> "FIA Stewards: "
        source == :stewards_correction -> "FIA Stewards correction: "
        emoji == :announcement -> "Race Control: "
        true -> ""
      end

    F1Bot.ExternalApi.Discord.post_message("#{emoji} #{source_prefix}#{message}")

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.info("Ignored output message: #{inspect(msg)}")
    {:noreply, state}
  end

  defp server_via() do
    __MODULE__
  end
end
