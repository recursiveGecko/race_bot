defmodule F1Bot.MixProject do
  use Mix.Project

  def project do
    [
      app: :f1_bot,
      version: "0.2.1",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/recursiveGecko/race_bot",
      homepage_url: "https://github.com/recursiveGecko/race_bot",
      compilers: Mix.compilers() ++ [:surface],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: [
        plt_add_deps: :apps_direct,
        plt_add_apps: [:nostrum, :mix],
        list_unused_filters: true
      ],
      releases: [
        f1bot: [
          include_executables_for: [:unix],
          applications: [
            runtime_tools: :permanent,
            observer: :load,
            nostrum: :load
          ],
          strip_beams: false
        ]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {F1Bot.Application, []}
    ]
  end

  def docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "LICENSE.md"
      ],
      groups_for_modules: [
        "Live Timing API": ~r/^F1Bot.ExternalApi.SignalR/,
        "F1 Session (boundary)": ~r/^F1Bot.F1Session.Server/,
        "F1 Session (functional)": ~r/^F1Bot.F1Session/,
        "Output servers": ~r/^F1Bot.Output/,
        Plotting: ~r/^F1Bot.Plotting/,
        "Other external APIs": ~r/^F1Bot.ExternalApi/
      ],
      groups_for_functions: [],
      source_ref: "master",
      nest_modules_by_prefix: [
        F1Bot.F1Session,
        F1Bot.Output,
        F1Bot.Plotting,
        F1Bot.ExternalApi.Discord,
        F1Bot.ExternalApi.Twitter,
        F1Bot.ExternalApi.SignalR
      ]
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  def aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:gun, "== 2.0.1", hex: :remedy_gun},
      {:cowlib, "~> 2.11.0", override: true},
      {:jason, "~> 1.2"},
      {:finch, "~> 0.9.1"},
      {:nostrum, "~> 0.5.1", runtime: false},
      {:phoenix_pubsub, "~> 2.0"},
      {:certifi, "~> 2.8"},
      {:typed_struct, "~> 0.2.1"},
      {:timex, "~> 3.7"},
      {:nimble_parsec, "~> 1.2"},
      {:contex, "~> 0.4.0"},
      {:mogrify, "~> 0.9.1"},
      {:gnuplot, "~> 1.20"},
      {:extwitter, "~> 0.13.0"},
      {:oauther, "~> 1.1"},
      {:scribe, "~> 0.10.0", only: :dev},
      {:kino, "~> 0.4.1", only: :dev},
      {:vega_lite, "~> 0.1.2", only: :dev},
      {:dialyxir, "~> 1.1", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", runtime: false, override: true},
      {:tailwind, "~> 0.1.9", runtime: Mix.env() == :dev},
      {:phoenix, "~> 1.6.12"},
      {:surface, "~> 0.8.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.6"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:plug_cowboy, "~> 2.5"}
    ]
  end
end
