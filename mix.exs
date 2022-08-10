defmodule Hemdal.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :hemdal,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      name: "Hemdal",
      docs: docs()
    ]
  end

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

  defp deps do
    [
      {:gen_state_machine, "~> 3.0"},
      {:gen_stage, "~> 1.1"},
      {:construct, "~> 2.1"},
      {:tesla, "~> 1.4"},
      {:jason, "~> 1.3"},

      # only for dev
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:doctor, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.14", only: [:dev, :test], runtime: false},
      {:ex_doc, ">= 0.0.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      release: [
        "clean",
        "deps.get",
        "compile",
        "release"
      ]
    ]
  end

  defp docs do
    [
      main: "Hemdal",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/hemdal",
      # logo: "guides/images/hemdal.png",
      extra_section: "GUIDES",
      source_url: "https://github.com/altenwald/hemdal",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      groups_for_modules: [
        "Event Producer/Consumers": [
          Hemdal.EventManager,
          Hemdal.EventLogger,
          Hemdal.EventNotif
        ],
        API: [
          Hemdal.Api.Slack
        ],
        "Alert/Alarms Logic": [
          Hemdal.Check,
          Hemdal.Host.Conn
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
          HemdalWeb.Router.Helpers
        ]
      ]
    ]
  end

  defp extras do
    [
      "guides/introduction/Getting_Started.md",
      "guides/operational/Creating_Alerts.md",
      "guides/operational/Notifying_to_Slack.md"
    ]
  end

  defp groups_for_extras do
    [
      Introduction: ~r/guides\/introduction\/.?/,
      Operational: ~r/guides\/operational\/.?/
    ]
  end
end
