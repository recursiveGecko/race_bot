# Used by "mix format"
[
  import_deps: [:ecto, :phoenix, :surface],
  inputs: [
    "*.{heex,ex,exs}",
    "{config,lib,test}/**/*.{heex,ex,exs}",
    "priv/*/seeds.exs",
    "{lib,test}/**/*.sface"
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter, Surface.Formatter.Plugin]
]
