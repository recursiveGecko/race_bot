defmodule F1BotWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :f1_bot

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_f1_bot_key",
    signing_salt: "ClYKEeTa"
  ]

  defp add_response_headers(conn, _opts) do
    conn
    |> put_resp_header("Referrer-Policy", "no-referrer")
  end

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]
  socket "/api-socket", F1BotWeb.ApiSocket,
    websocket: true,
    longpoll: false

  plug F1BotWeb.HealthCheck,
    path: "/health-check"

  # Serve at "/" the static files from "priv/static" directory.
  plug Plug.Static,
    at: "/",
    from: :f1_bot,
    gzip: true,
    only: F1BotWeb.static_paths(),
    # Favicon with digest suffix is served from root and doesn't get
    # matched by the above rule, ":only" only matches exact paths and files
    # inside matching subdirectories, here we allow an arbitrary suffix
    # for files in root
    only_matching: ~w(favicon)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :f1_bot
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options

  plug F1BotWeb.Plug.UserUUID

  plug :add_response_headers

  plug F1BotWeb.Router
end
