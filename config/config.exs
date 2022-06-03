import Config

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
    "Heartbeat"
    # Session time remaining and real time clock sync
    # "ExtrapolatedClock",
    #  "AudioStreams",
  ]

# config :logger, :console, metadata: [:mfa]

import_config "#{Mix.env()}.exs"
