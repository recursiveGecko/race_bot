defmodule F1Bot.MixProject do
  use Mix.Project

  def project do
    [
      app: :f1_bot,
      version: "0.1.0",
      elixir: "~> 1.13",
      source_url: "https://github.com/recursiveGecko/race_bot",
      homepage_url: "https://github.com/recursiveGecko/race_bot",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: [plt_add_deps: :apps_direct, plt_add_apps: [:nostrum, :mix]],
      releases: [
        f1bot: [
          include_executables_for: [:unix],
          applications: [
            runtime_tools: :permanent,
            observer: :load,
            nostrum: :load
          ]
        ]
      ]
    ]
  end

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
        "LICENSE.md",
      ],
      groups_for_modules: [
        "Live Timing API": ~r/^F1Bot.ExternalApi.SignalR/,
        "F1 Live Timing Handlers": ~r/^F1Bot.LiveTimingHandlers/,
        "F1 Session (boundary)": ~r/^F1Bot.F1Session(.Server|$)/,
        "F1 Session (functional)": ~r/^F1Bot.F1Session/,
        "Output servers": ~r/^F1Bot.Output/,
        Plotting: ~r/^F1Bot.Plotting/,
        "Other external APIs": ~r/^F1Bot.ExternalApi/
      ],
      groups_for_functions: [],
      source_ref: "master",
      nest_modules_by_prefix: [
        F1Bot.F1Session,
        F1Bot.LiveTimingHandlers,
        F1Bot.Output,
        F1Bot.Plotting,
        F1Bot.ExternalApi.Discord,
        F1Bot.ExternalApi.Twitter,
        F1Bot.ExternalApi.SignalR
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:gun, "== 2.0.1", hex: :remedy_gun},
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
      {:ex_doc, "~> 0.28", runtime: false, override: true}
    ]
  end
end
