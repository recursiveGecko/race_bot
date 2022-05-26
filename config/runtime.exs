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

if config_env() != :test do
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
