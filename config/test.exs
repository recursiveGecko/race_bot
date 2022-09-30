import Config

config :f1_bot,
  connect_to_signalr: false,
  start_discord: false,
  start_twitter: false,
  discord_api_module: F1Bot.ExternalApi.Discord.Console,
  twitter_api_module: F1Bot.ExternalApi.Twitter.Console

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :f1_bot, F1Bot.Repo,
  database: Path.expand("../f1bot_test.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :f1_bot, F1BotWeb.Endpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jCvmuMYzhlV6gYjGyhfx9EQx8opC4ZdOy4E5xS1fti38f6L9SeaUAUAeqyt4ZXMv",
  live_view: [signing_salt: "nDtTgwk3"],
  server: false

config :f1_bot, F1BotWeb.InternalEndpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base: "rmcLIUvCsAQzDrAJIz/36NFPe4eo1zpD4nL85nHzzgQmy8JI33GuCUeVqSJnisjX",
  live_view: [signing_salt: "M85ifOQO13BPHueM2huMVoFzN90ACBfU"],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
