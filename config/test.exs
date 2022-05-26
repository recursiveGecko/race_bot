import Config

config :f1_bot,
  connect_to_signalr: false,
  external_apis_enabled: false,
  discord_api_module: F1Bot.ExternalApi.Discord.Console,
  twitter_api_module: F1Bot.ExternalApi.Twitter.Console
