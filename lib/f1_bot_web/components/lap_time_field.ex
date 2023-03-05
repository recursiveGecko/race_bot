defmodule F1BotWeb.Component.LapTimeField do
  use F1BotWeb, :component
  alias F1Bot.DataTransform.Format

  prop id, :string, required: true
  prop class, :css_class
  prop stat, :map, required: true
  prop overall_fastest_class, :css_class, default: "border-purple-600"
  prop personal_fastest_class, :css_class, default: "border-green-600"
  prop not_fastest_class, :css_class, default: "border-transparent"
  prop can_drop_minute, :boolean, default: true

  @impl true
  def render(assigns) do
    ~F"""
    <span
      id={@id}
      :hook={"HighlightOnChange", from: Component.Utility}
      class={
        "inline-block font-roboto px-1 rounded border border-b-2 w-14 min-w-max text-center",
        @class,
        class_for_best_type(
          stat: @stat,
          overall_fastest_class: @overall_fastest_class,
          personal_fastest_class: @personal_fastest_class,
          not_fastest_class: @not_fastest_class
        )
      }
    >
      {format_value(@stat, @can_drop_minute)}
    </span>
    """
  end

  defp format_value(stat, can_drop_minute) do
    case stat.value do
      nil -> "—"
      value -> Format.format_lap_time(value, can_drop_minute)
    end
  end

  defp class_for_best_type(options) do
    best_type = options[:stat][:best]

    case best_type do
      :overall -> options[:overall_fastest_class]
      :personal -> options[:personal_fastest_class]
      _ -> options[:not_fastest_class]
    end
  end
end
