import Config

config :tesla, disable_deprecated_builder_warning: true

if config_env() == :test do
  config :tesla, adapter: Tesla.Mock
end

if config_env() == :dev do
  config :hemdal, :config_module, Hemdal.Config.Backend.Env

  config :hemdal, Hemdal.Config, []
end
