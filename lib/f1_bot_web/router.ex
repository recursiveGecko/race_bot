defmodule F1BotWeb.Router do
  use F1BotWeb, :router

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

  scope "/", F1BotWeb do
    pipe_through :browser

    live "/", Live.Telemetry
    live "/chart", Live.Chart
  end
end
