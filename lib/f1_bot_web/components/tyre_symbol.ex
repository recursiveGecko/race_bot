defmodule F1BotWeb.Component.TyreSymbol do
  @moduledoc """
  A component that renders a tyre symbol.

  Thanks to https://github.com/f1multiviewer for the tyre SVG path.
  """
  use Surface.Component

  prop class, :css_class
  prop tyre_age, :number, required: true
  prop compound, :any, required: true

  @impl true
  def render(assigns) do
    ~F"""
    <span title={"#{String.capitalize("#{@compound}")} compound (#{@tyre_age} laps old)"}>
      <svg class={@class} viewBox="0 0 95 38">
        <text
          font-family="'Exo 2'"
          font-weight="800"
          fill="black"
          x="20%"
          y="72%"
          font-size="21"
          text-anchor="middle"
        >
          {letter_for_compound(@compound)}
        </text>
        <path
          d={if @tyre_age in [0, nil] do
            "M16 3a17.3 17.3 0 0 0 0 34v-4.1a13.2 13.2 0 0 1 0-25.8V3Zm6.1 29.9a13.2 13.2 0 0 0 0-25.8V3a17.3 17.3 0 0 1 0 34v-4.1Z"
          else
            "M34 .8 38.3 5l-5 5a17.2 17.2 0 0 1-11 27v-4.3a13.2 13.2 0 0 0 0-25.6V3A18 18 0 0 1 29 5.8l5-5ZM5 29.7.3 34.5l4.3 4.3L9.3 34c2 1.4 4.4 2.4 7 2.9v-4.2a13.2 13.2 0 0 1 0-25.6V3A17.2 17.2 0 0 0 5 29.7Z"
          end}
          fill={color_for_compound(@compound)}
        />
        <text
          font-family="'Exo 2'"
          font-weight="700"
          fill="black"
          x="50%"
          y="72%"
          font-size="21"
          text-anchor="start"
        >
          {age_text(@tyre_age)}
        </text>
      </svg>
    </span>
    """
  end

  defp color_for_compound(compound) do
    case compound do
      :soft -> "#DA291C"
      :medium -> "#FFD100"
      :hard -> "#c4c4c0"
      :intermediate -> "#43B02A"
      :wet -> "#0067AD"
      _ -> "##ffffff4d"
    end
  end

  defp letter_for_compound(compound) do
    case compound do
      :soft -> "S"
      :medium -> "M"
      :hard -> "H"
      :intermediate -> "I"
      :wet -> "W"
      _ -> "?"
    end
  end

  defp age_text(tyre_age) do
    if tyre_age in [0, nil] do
      "New"
    else
      "#{tyre_age} L"
    end
  end
end
