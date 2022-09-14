import Config

config :f1_bot,
  ecto_repos: [F1Bot.Repo]

# Configures the endpoint
config :f1_bot, F1BotWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: F1BotWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: F1Bot.PubSub,
  live_view: [signing_salt: "nDtTgwk3"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind, version: "3.1.8", default: [
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

config :f1_bot,
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
    #  "AudioStreams",
  ]

# config :logger, :console, metadata: [:mfa]

import_config "#{Mix.env()}.exs"
