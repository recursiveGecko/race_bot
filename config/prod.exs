import Config

config :f1_bot,
  connect_to_signalr: true,
  external_apis_enabled: true,
  discord_api_module: F1Bot.ExternalApi.Discord.Live,
  twitter_api_module: F1Bot.ExternalApi.Twitter.Live

config :logger,
  level: :info

config :logger, :console, metadata: [:error_code, :line, :mfa]
