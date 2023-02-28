defmodule F1BotWeb.Component.CoreComponents do
  use Phoenix.Component
  use F1BotWeb, :verified_routes

  attr :class, :string, default: ""
  def brand(assigns) do
    ~H"""
    <a class={["text-xl flex items-center", @class]} href={~p"/"}>
      <img class="h-14 mr-3" src={~p"/favicon.png"} alt="logo" />
      <span class="text-2xl">
        Race Bot for F1
        <%= if F1Bot.demo_mode?() do %>
          | Demo
        <% end %>
      </span>
    </a>
    """
  end

  attr :class, :string, default: ""
  def other_site_link(assigns) do
    {other_site_name, other_site_link} =
      if F1Bot.demo_mode?() do
        {"Live Site", "https://racing.recursiveprojects.cloud"}
      else
        {"Demo Site", "https://racing-dev.recursiveprojects.cloud"}
      end

    assigns =
      assigns
      |> assign(:other_site_name, other_site_name)
      |> assign(:other_site_link, other_site_link)

    ~H"""
    <a class={["inline-flex items-center font-semibold", @class]} href={@other_site_link}>
      <Heroicons.arrow_top_right_on_square mini class="w-5 h-5 mr-1"/>
      <%= @other_site_name %>
    </a>
    """
  end
end
