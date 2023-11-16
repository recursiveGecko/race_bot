defmodule F1Bot.ExternalApi.Discord.Commands.Summary do
  @moduledoc """
  Handles Discord command for displaying driver's session summary
  """
  require Logger
  alias Nostrum.Struct.Interaction
  alias F1Bot
  alias F1Bot.F1Session.DriverDataRepo.Summary
  alias F1Bot.F1Session.DriverCache.DriverInfo
  alias F1Bot.ExternalApi.Discord
  alias F1Bot.ExternalApi.Discord.Permissions
  alias F1Bot.ExternalApi.Discord.Commands.{Response, OptionValidator}

  @behaviour Discord.Commands

  @impl Discord.Commands
  def handle_interaction(interaction = %Interaction{}, internal_args) do
    flags = Map.get(internal_args, :flags, [])

    case parse_interaction_options(interaction) do
      {:ok, parsed_opts} ->
        flags
        |> Response.make_deferred_message()
        |> Response.send_interaction_response(interaction)

        do_create_summary(interaction, parsed_opts, internal_args)

      {:error, option_error} ->
        flags
        |> Response.make_message("Error: #{option_error}")
        |> Response.send_interaction_response(interaction)
    end
  end

  defp do_create_summary(interaction, options, internal_args) do
    flags = Map.get(internal_args, :flags, [])

    use_emojis =
      case Permissions.everyone_has_external_emojis?(interaction.guild_id) do
        {:ok, perm} -> perm
        _ -> false
      end

    {:ok, session_info} = F1Bot.session_info()
    track_status_history = F1Bot.track_status_history()

    embed_results =
      for driver_number <- options.drivers do
        with {:ok, driver_info} <- F1Bot.driver_info_by_number(driver_number),
             {:ok, driver_data} <- F1Bot.driver_session_data(driver_number),
             {:ok, best_stats} <- F1Bot.session_best_stats() do
          summary = Summary.generate(driver_data, track_status_history, best_stats)
          embed = generate_summary_embed(session_info, driver_info, summary, use_emojis)
          {:ok, embed}
        else
          {:error, error} ->
            {:error, {driver_number, error}}
        end
      end

    embeds =
      embed_results
      |> Enum.filter(fn {status, maybe_err} ->
        if status == :error do
          {driver_number, error} = maybe_err

          Logger.error(
            "Failed to generate summary for driver #{driver_number}: #{inspect(error)}"
          )
        end

        status == :ok
      end)
      |> Enum.map(fn {_status, embed} -> embed end)

    flags
    |> Response.make_followup_message(nil, [], embeds)
    |> Response.send_followup_response(interaction)
  end

  defp generate_summary_embed(session_info, driver_info, summary, use_emojis) do
    stats = summary.stats

    %{
      type: "rich",
      color: DriverInfo.team_color_int(driver_info),
      title: driver_info.full_name,
      description: "#{session_info.gp_name} - #{session_info.type}",
      thumbnail: %{
        url: driver_info.picture_url
      },
      fields:
        [
          %{
            inline: true,
            name: "Fastest S1",
            value: format_lap_time(stats.s1_time.fastest.value)
          },
          %{
            inline: true,
            name: "Fastest S2",
            value: format_lap_time(stats.s2_time.fastest.value)
          },
          %{
            inline: true,
            name: "Fastest S3",
            value: format_lap_time(stats.s3_time.fastest.value)
          },
          %{
            inline: true,
            name: "Fastest lap",
            value: format_lap_time(stats.lap_time.fastest.value)
          },
          %{inline: true, name: "Top speed", value: format_speed(stats.top_speed.value)},
          %{
            inline: true,
            name: "Ideal lap",
            value: format_lap_time(stats.lap_time.theoretical.value)
          }
        ] ++ generate_stint_fields(summary, use_emojis),
      footer: %{
        text:
          """
          Letter and number in parentheses - tyre compound and age when fitted (laps)
          Timed laps - # of laps included in statistics (excludes outlaps, VSC, SC, red flag)
          """
          |> String.trim()
      }
    }
  end

  defp generate_stint_fields(summary, use_emojis) do
    for stint <- summary.stints do
      stint_info = "Stint #{stint.number + 1}"
      laps_info = "Lap #{stint.lap_start}-#{stint.lap_end}" |> format_width(9)
      timed_laps_info = "Timed laps: #{stint.timed_laps}" |> format_width(15)
      tyre_info = gen_stint_tyre_info(stint, use_emojis)

      first_row = "#{tyre_info} `#{stint_info}  #{laps_info}   #{timed_laps_info}`"

      avg_lap = format_lap_time(stint.stats.lap_time.average.value) |> format_width(8)
      fast_lap = format_lap_time(stint.stats.lap_time.fastest.value) |> format_width(8)

      second_row = "`Lap (min/avg):  #{fast_lap} /  #{avg_lap} `"

      %{
        inline: false,
        name: first_row,
        value: second_row
      }
    end
  end

  defp gen_stint_tyre_info(stint, use_emojis) do
    tyre_emoji =
      "#{stint.compound}_tyre"
      |> String.to_atom()
      |> Discord.get_emoji_with_env_override()

    tyre_ascii =
      stint.compound
      |> to_string()
      |> String.first()
      |> to_string()
      |> String.upcase()

    age_info = "(#{stint.tyre_age || 0})"

    if use_emojis do
      "#{tyre_emoji}`#{age_info}`"
    else
      "`#{tyre_ascii} #{age_info} `"
    end
  end

  defp format_width(text, width), do: String.pad_trailing(text, width)

  defp format_lap_time(_time = nil), do: "N/A"

  defp format_lap_time(time = %Timex.Duration{}),
    do: F1Bot.DataTransform.Format.format_lap_time(time)

  defp format_speed(_speed = nil), do: "N/A"

  defp format_speed(speed), do: "#{speed} km/h"

  defp parse_interaction_options(interaction = %Interaction{}) do
    %Interaction{
      data: %{
        options: options
      }
    } = interaction

    with {:ok, drivers} <- OptionValidator.validate_driver_list(options, "drivers"),
         true <- length(drivers) <= 10 do
      opts = %{
        drivers: drivers
      }

      {:ok, opts}
    else
      false -> {:error, "You may provide a list of up to 10 drivers."}
      {:error, error} -> {:error, error}
    end
  end
end
