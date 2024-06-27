defmodule F1Bot.MixProject do
  use Mix.Project

  def project do
    [
      app: :f1_bot,
      version: "0.7.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      source_url: "https://github.com/recursiveGecko/race_bot",
      homepage_url: "https://github.com/recursiveGecko/race_bot",
      compilers: Mix.compilers() ++ [:surface],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
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
      extra_applications: [:logger, :tools, :observer, :wx],
      mod: {F1Bot.Application, []}
    ]
  end

  defp docs do
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
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        "cmd --cd assets npm install --ignore-scripts"
      ],
      "assets.build": ["hooks.build", "tailwind default", "esbuild default"],
      "assets.deploy": [
        "hooks.build",
        "tailwind default --minify",
        "esbuild default --minify",
        "phx.digest"
      ],
      # Builds Surface UI hooks -> ./assets/js/_hooks
      "hooks.build": ["compile"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:finch, "~> 0.18.0"},
      {:fresh, "~> 0.4.4"},
      {
        :nostrum,
        # Includes https://github.com/Kraigie/nostrum/pull/522
        git: "https://github.com/Kraigie/nostrum",
        ref: "4fabfc5bf59878fdde118acd686f6a5e075b5f8e",
        runtime: false
      },
      {:certifi, "~> 2.9"},
      {:typed_struct, "~> 0.3.0"},
      {:timex, "~> 3.7"},
      {:nimble_parsec, "~> 1.2"},
      {:contex, "~> 0.4.0"},
      {:mogrify, "~> 0.9.2"},
      {:gnuplot, "~> 1.22"},
      {:scribe, "~> 0.10.0", only: :dev},
      {:kino, "~> 0.8.1", only: :dev},
      {:vega_lite, "~> 0.1.6", only: :dev},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.29", runtime: false, override: true},
      {:tailwind, "~> 0.1.9", runtime: Mix.env() == :dev},
      {:phoenix, "~> 1.7", override: true},
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.4", only: :dev},
      {:phoenix_live_dashboard, "~> 0.7.2"},
      {:phoenix_live_view, "~> 0.18.15"},
      {:surface, "~> 0.9.4"},
      {:ecto_sql, "~> 3.9"},
      {:ecto_sqlite3, "~> 0.9.1"},
      {:floki, ">= 0.34.0", only: :test},
      {:esbuild, "~> 0.6.1", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6.1"},
      {:telemetry_poller, "~> 1.0"},
      {:plug_cowboy, "~> 2.6"},
      {:heroicons, "~> 0.5.2"},
      # {:flame_on, "~> 0.5.2", only: :dev},
      {:eflame, "~> 1.0"},
      {:rexbug, ">= 2.0.0-rc1"}
    ]
  end
end
