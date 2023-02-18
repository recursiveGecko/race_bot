defmodule F1BotWeb.InternalRouter do
  use F1BotWeb, :router
  import Phoenix.LiveDashboard.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {F1BotWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :browser

    live "/site", F1BotWeb.Live.Telemetry

    live_dashboard "/",
      metrics: F1BotWeb.Telemetry,
      additional_pages: [
        # TODO: Current flame_on doesn't support phoenix_live_dashboard 0.7.x
        # flame_on: FlameOn.DashboardPage
      ]
  end
end
