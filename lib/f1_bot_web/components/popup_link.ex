defmodule F1BotWeb.Component.PopupLink do
  # SVG icon: https://heroicons.com/

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

      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 inline-block">
        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 6H5.25A2.25 2.25 0 003 8.25v10.5A2.25 2.25 0 005.25 21h10.5A2.25 2.25 0 0018 18.75V10.5m-10.5 6L21 3m0 0h-5.25M21 3v5.25" />
      </svg>
    </button>
    """
  end
end
