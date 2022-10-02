import Config

config :f1_bot,
  connect_to_signalr: false,
  start_discord: false,
  start_twitter: false,
  discord_api_module: F1Bot.ExternalApi.Discord.Console,
  twitter_api_module: F1Bot.ExternalApi.Twitter.Console

config :logger,
  level: :info

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Configure your database
config :f1_bot, F1Bot.Repo,
  database: Path.expand("../f1bot_dev.db", Path.dirname(__ENV__.file)),
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with esbuild to bundle .js and .css sources.
config :f1_bot, F1BotWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "U/lrJxiO8Pof0MWxTnEHM+CvYJ4559nfslojhRY3ui9hEcZX5N3bUrpGPRtKLX8b",
  watchers: [
    # Start the esbuild watcher by calling Esbuild.install_and_run(:default, args)
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ],
  # Watch static and templates for browser reloading.
  reloadable_compilers: [:gettext, :elixir, :surface],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/f1_bot_web/(live|views|components)/.*(ex|sface|js)$",
      ~r"lib/f1_bot_web/templates/.*(eex|sface)$"
    ]
  ]

config :f1_bot, F1BotWeb.InternalEndpoint,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: 4001],
  check_origin: false,
  debug_errors: true,
  secret_key_base: "kIaE5yMJsNdbC2xW+TtE/ImirvCTyyzkOoftsQPWimDQHfZnwXkx/4sWIww9hWt0",
  live_view: [signing_salt: "AOtJEjcdsssJpmsFIkNl6ksdtAQuwavZ"]

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime
