import Config

if config_env() == :test do
  config :req, default_options: [plug: {Req.Test, Hemdal.Notifier}]
end

if config_env() == :dev do
  config :hemdal, :config_module, Hemdal.Config.Backend.Env

  config :hemdal, Hemdal.Config, []
end
