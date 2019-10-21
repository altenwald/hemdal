defmodule Hemdal.MixProject do
  use Mix.Project

  def project do
    [
      app: :hemdal,
      version: "0.2.1",
      elixir: "~> 1.8",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
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
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},
      {:tesla, "~> 1.1.0"},
      {:trooper, "~> 0.3.0"},
      {:timex, "~> 3.6"},

      # for releases
      {:distillery, "~> 2.0"},
      {:ecto_boot_migration, "~> 0.2.0"},
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
end
