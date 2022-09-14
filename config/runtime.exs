import Config

# Handles both comma-separated values and multiline values with comments
list_from_env = fn env_var ->
  env_var
  |> System.fetch_env!()
  |> String.replace(~r/#.*/, "")
  |> String.replace("\n", ",")
  |> String.split(",")
  |> Enum.map(&String.trim/1)
  |> Enum.filter(&(String.length(&1) > 0))
end

list_to_int = fn list -> for x <- list, do: String.to_integer(x) end

demo_mode_url = System.get_env("DEMO_MODE_URL", "")
demo_mode_enabled = String.starts_with?(demo_mode_url, "http")

# Configure application for demo mode
if demo_mode_enabled do
  config :f1_bot,
    env: :demo,
    demo_mode_url: demo_mode_url

  config :f1_bot,
    connect_to_signalr: false,
    external_apis_enabled: false,
    discord_api_module: F1Bot.ExternalApi.Discord.Console,
    twitter_api_module: F1Bot.ExternalApi.Twitter.Console
end

if config_env() == :prod do
  unless demo_mode_enabled do
    config :f1_bot,
      connect_to_signalr: true,
      external_apis_enabled: true,
      discord_api_module: F1Bot.ExternalApi.Discord.Live,
      twitter_api_module: F1Bot.ExternalApi.Twitter.Live

    config :nostrum,
      token: System.fetch_env!("DISCORD_TOKEN")

    config :f1_bot,
      extwitter_config: [
        consumer_key: System.fetch_env!("TWITTER_CONSUMER_KEY"),
        consumer_secret: System.fetch_env!("TWITTER_CONSUMER_SECRET"),
        access_token: System.fetch_env!("TWITTER_ACCESS_TOKEN"),
        access_token_secret: System.fetch_env!("TWITTER_ACCESS_TOKEN_SECRET")
      ],
      discord_channel_ids_messages:
        list_from_env.("DISCORD_CHANNEL_IDS_MESSAGES") |> list_to_int.(),
      discord_server_ids_commands: list_from_env.("DISCORD_SERVER_IDS_COMMANDS") |> list_to_int.()
  end

  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/f1bot/f1bot.db
      """

  config :f1_bot, F1Bot.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host =
    System.get_env("PHX_HOST") ||
      raise """
      environment variable PHX_HOST is missing.
      """

  port =
    case System.get_env("PORT") do
      nil ->
        raise """
        environment variable PORT is missing.
        """

      port ->
        String.to_integer(port)
    end

  config :f1_bot, F1BotWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base
end

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/f1bot start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.

if System.get_env("PHX_SERVER") do
  config :f1_bot, F1BotWeb.Endpoint, server: true
end
