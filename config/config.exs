import Config

config :gnuplot,
  timeout: {3000, :ms}

# config :logger, :console, metadata: [:mfa]

import_config "#{Mix.env()}.exs"
