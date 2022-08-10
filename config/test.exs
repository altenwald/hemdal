import Config

# Print only warnings and errors during test
config :logger, level: :debug

config :hemdal,
  log_all_events: false,
  config_module: Hemdal.Config.Backend.Json

config :hemdal, Hemdal.Config,
  hosts_file: "test/resources/hosts_config.json",
  alerts_file: "test/resources/alerts_config.json"
