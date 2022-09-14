defmodule F1BotWeb.LayoutView do
  use F1BotWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def phx_host() do
    F1Bot.get_env(F1BotWeb.Endpoint)[:url][:host]
  end
end
