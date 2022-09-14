# Used by "mix format"
[
  import_deps: [:ecto, :phoenix, :surface],
  inputs: [
    "*.{ex,exs}",
    "priv/*/seeds.exs",
    "{config,lib,test}/**/*.{ex,exs}",
    "{lib,test}/**/*.sface"
  ],
  subdirectories: ["priv/*/migrations"],
  plugins: [Surface.Formatter.Plugin]
]
