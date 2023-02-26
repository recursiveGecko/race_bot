import Config

config :f1_bot,
  ecto_repos: [F1Bot.Repo],
  signalr_topics: [
    "TrackStatus",
    "TeamRadio",
    "RaceControlMessages",
    "SessionInfo",
    "SessionStatus",
    "TimingAppData",
    "TimingData",
    "DriverList",
    "WeatherData",
    # Car telemetry
    "CarData.z",
    # Car position (GPS)
    "Position.z",
    "Heartbeat",
    # Session time remaining and real time clock sync
    "ExtrapolatedClock",
    # Session-wise current lap counter and total # of laps
    "LapCount"
  ]

# Configures the endpoint
config :f1_bot, F1BotWeb.Endpoint,
  render_errors: [
    formats: [html: F1BotWeb.ErrorHTML, json: F1BotWeb.ErrorJSON],
    layout: false
  ],
  live_view: [signing_salt: "nDtTgwk3"],
  pubsub_server: F1Bot.PubSub

config :f1_bot, F1BotWeb.InternalEndpoint,
  render_errors: [
    formats: [html: F1BotWeb.ErrorHTML, json: F1BotWeb.ErrorJSON],
    layout: false
  ],
  live_view: [signing_salt: "BlByFUSB8j91iHK0qEAfCcjXHGvQBxjs"],
  pubsub_server: F1Bot.PubSub

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(assets/js/app.ts --bundle --target=es2017 --outdir=priv/static/assets --tsconfig=tsconfig.json --external:/fonts/* --external:/images/*)
  ]

config :tailwind,
  version: "3.2.7",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :gnuplot,
  timeout: {3000, :ms}

# config :logger, :console, metadata: [:mfa]

import_config "#{Mix.env()}.exs"
