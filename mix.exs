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
      start_phases: [load_checks: []]
    ]
  end

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
        "Alert/Alarms Logic": [
          Hemdal,
          Hemdal.Check
        ],
        Configuration: [
          Hemdal.Config,
          Hemdal.Config.Alert,
          Hemdal.Config.Alert.Command,
          Hemdal.Config.Host,
          Hemdal.Config.Notifier,
          Hemdal.Config.Module,
          Hemdal.Config.Options
        ],
        "Configuration Backend": [
          Hemdal.Config.Backend,
          Hemdal.Config.Backend.Env,
          Hemdal.Config.Backend.Json
        ],
        Hosts: [
          Hemdal.Host,
          Hemdal.Host.Local
        ],
        "Event Producer/Consumers": [
          Hemdal.Event,
          Hemdal.Event.Log,
          Hemdal.Event.Notification,
          Hemdal.Event.Mock
        ],
        Notifiers: [
          Hemdal.Notifier,
          Hemdal.Notifier.Slack,
          Hemdal.Notifier.Mattermost,
          Hemdal.Notifier.Mock
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
