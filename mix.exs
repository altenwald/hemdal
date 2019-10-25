defmodule Hemdal.MixProject do
  use Mix.Project

  @version "0.5.1"

  def project do
    [
      app: :hemdal,
      version: @version,
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "Hemdal",
      docs: docs(),
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Hemdal.Application, []},
      extra_applications: [:logger, :runtime_tools],
      start_phases: [load_checks: run_load_checks(Mix.env())]
    ]
  end

  defp run_load_checks(:test), do: [:ignore]
  defp run_load_checks(_), do: []

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:gen_state_machine, "~> 2.0"},
      {:gen_stage, "~> 0.14"},
      {:uuid, "~> 1.1"},
      {:phoenix, "~> 1.4.9"},
      {:phoenix_pubsub, "~> 1.1"},
      {:phoenix_ecto, "~> 4.0"},
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 2.11"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:tesla, "~> 1.1.0"},
      {:trooper, "~> 0.3.0"},
      {:timex, "~> 3.6"},

      # for releases
      {:distillery, "~> 2.0"},
      {:ecto_boot_migration, "~> 0.2.0"},

      # only for dev
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.19.0", only: :dev},
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.drop",
             "ecto.create",
             "ecto.migrate",
             "run priv/repo/seeds.exs",
             "run priv/repo/test_seeds.exs",
             "test --cover"]
    ]
  end

  defp docs do
    [
      main: "Hemdal",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/hemdal",
      #logo: "guides/images/hemdal.png",
      extra_section: "GUIDES",
      source_url: "https://github.com/altenwald/hemdal",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: [
        "Models": [
          Hemdal.Alert,
          Hemdal.AlertNotif,
          Hemdal.Command,
          Hemdal.Cred,
          Hemdal.Group,
          Hemdal.Host,
          Hemdal.Notif,
          Hemdal.Log,
          Hemdal.Repo,
        ],
        "Event Producer/Consumers": [
          Hemdal.EventManager,
          Hemdal.EventChannel,
          Hemdal.EventLogger,
          Hemdal.EventNotif,
        ],
        "API": [
          Hemdal.Api.Slack,
        ],
        "Alert/Alarms Logic": [
          Hemdal.Check,
          Hemdal.Host.Conn,
        ],
        "Web Interface": [
          Hemdal.CheckChannel,
          HemdalWeb,
          HemdalWeb.CheckSocket,
          HemdalWeb.Endpoint,
          HemdalWeb.ErrorHelpers,
          HemdalWeb.ErrorView,
          HemdalWeb.Gettext,
          HemdalWeb.LayoutView,
          HemdalWeb.PageController,
          HemdalWeb.PageView,
          HemdalWeb.Router,
          HemdalWeb.Router.Helpers,
        ]
      ]
    ]
  end

  defp extras do
    [
      "guides/introduction/Getting_Started.md",
      "guides/operational/Creating_Alerts.md",
      "guides/operational/Notifying_to_Slack.md",
    ]
  end

  defp groups_for_extras do
    [
      "Introduction": ~r/guides\/introduction\/.?/,
      "Operational": ~r/guides\/operational\/.?/,
    ]
  end
end
