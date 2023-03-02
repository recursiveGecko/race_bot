defmodule F1BotWeb.Component.LapTimeField do
  use F1BotWeb, :component
  alias F1Bot.DataTransform.Format

  prop id, :string, required: true
  prop class, :css_class
  prop stats, :map, required: true
  prop personal_best_stats, :map, required: true
  prop session_best_stats, :map, required: true
  prop kind, :any, required: true
  prop overall_fastest_class, :css_class, default: "border-purple-600"
  prop personal_fastest_class, :css_class, default: "border-green-600"
  prop not_fastest_class, :css_class, default: "border-transparent"

  @impl true
  def render(assigns) do
    ~F"""
    <span class={
      "inline-block font-roboto",
      @class,
      class_for_fastest_type(
        stats: @stats,
        personal_best_stats: @personal_best_stats,
        session_best_stats: @session_best_stats,
        kind: @kind,
        overall_fastest_class: @overall_fastest_class,
        personal_fastest_class: @personal_fastest_class,
        not_fastest_class: @not_fastest_class
      )
    }>
      <span id={@id} :hook={"HighlightOnChange", from: Component.Utility}>
        {format_value(@stats, @kind)}
      </span>
    </span>
    """
  end

  defp format_value(stats, kind) do
    maybe_drop_minutes =
      case kind do
        {:fastest_sector, _} -> true
        {:average_sector, _} -> true
        _ -> false
      end

    case extract_stat(stats, kind) do
      nil -> "—"
      value -> Format.format_lap_time(value, maybe_drop_minutes)
    end
  end

  defp class_for_fastest_type(options) do
    case fastest_type(options) do
      :overall -> options[:overall_fastest_class]
      :personal -> options[:personal_fastest_class]
      _ -> options[:not_fastest_class]
    end
  end

  defp fastest_type(options) do
    session_stat = extract_session_stat(options[:session_best_stats], options[:kind])
    pb_stat = extract_stat(options[:personal_best_stats], options[:kind])
    our_stat = extract_stat(options[:stats], options[:kind])

    cond do
      our_stat == nil -> nil
      pb_stat == nil -> nil
      session_stat == nil -> nil
      our_stat == session_stat -> :overall
      our_stat == pb_stat -> :personal
      true -> nil
    end
  end

  defp extract_stat(stats, _kind = :fastest_lap), do: stats[:lap_time][:fastest]
  defp extract_stat(stats, _kind = :average_lap), do: stats[:lap_time][:average]
  defp extract_stat(stats, _kind = :theoretical_fl), do: stats[:lap_time][:theoretical]
  defp extract_stat(stats, _kind = {:fastest_sector, 1}), do: stats[:s1_time][:fastest]
  defp extract_stat(stats, _kind = {:fastest_sector, 2}), do: stats[:s2_time][:fastest]
  defp extract_stat(stats, _kind = {:fastest_sector, 3}), do: stats[:s3_time][:fastest]
  defp extract_stat(stats, _kind = {:average_sector, 1}), do: stats[:s1_time][:average]
  defp extract_stat(stats, _kind = {:average_sector, 2}), do: stats[:s2_time][:average]
  defp extract_stat(stats, _kind = {:average_sector, 3}), do: stats[:s3_time][:average]

  defp extract_session_stat(session_stats, _kind = :fastest_lap), do: session_stats[:fastest_lap]
  defp extract_session_stat(stats, _kind = {:fastest_sector, 1}), do: stats[:fastest_sectors][1]
  defp extract_session_stat(stats, _kind = {:fastest_sector, 2}), do: stats[:fastest_sectors][2]
  defp extract_session_stat(stats, _kind = {:fastest_sector, 3}), do: stats[:fastest_sectors][3]
  defp extract_session_stat(_stats, _kind), do: nil
end
