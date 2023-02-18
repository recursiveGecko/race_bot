defmodule F1BotWeb.Component.PopupLink do
  use F1BotWeb, :component

  prop id, :string, required: true
  prop href, :uri, required: true
  prop class, :css_class, default: ""
  prop width, :integer, default: 1000
  prop height, :integer, default: 500
  slot default, required: true

  @impl true
  def render(assigns) do
    ~F"""
    <button id={@id}
            class={"inline-flex items-center font-semibold text-white rounded", "bg-blue-500", "hover:bg-blue-700", "py-1 px-2", @class}
            data-href={@href}
            data-width={@width}
            data-height={@height}
            :hook>
      <span class="mr-1">
        <#slot />
      </span>

      <Heroicons.arrow_top_right_on_square mini class="w-5 h-5"/>
    </button>
    """
  end
end
