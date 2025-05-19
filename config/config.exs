import Config

if config_env() == :dev do
  config :hemdal, :config_module, Hemdal.Config.Backend.Env

  config :hemdal, Hemdal.Config, []
end
