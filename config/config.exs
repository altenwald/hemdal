# this configuration is intended for testing purposes
import Config

config :hemdal,
  log_all_events: false,
  config_module: Hemdal.Config.Backend.Env

config :hemdal, Hemdal.Config, [
  [
    id: "b60c4bd2-6d0d-4cbd-bbc5-6985226f9fee",
    name: "check ssh",
    host: [
      id: "43debde2-424b-4751-b53c-eb037c5ea2d5",
      type: "Local",
      name: "server1"
    ],
    command: [
      id: "b446c60d-eba9-4be9-a87c-b801b4c51696",
      name: "check ssh",
      command_type: "script",
      command: "echo '[\"OK\", \"Hello world\"]'"
    ],
    notifiers: [
      [
        id: "b337687e-784c-4bb9-af2f-623e8238b4b1",
        token: "/services/T052XFQAE/B1705659P/zMoaWhzu8yhBWOtRWRU97bdP",
        username: "hemdal",
        type: "Slack",
        metadata: %{"icon" => "heimdall", "channel" => "#alerts"}
      ],
      [
        id: "3c282db4-7cce-499e-a1aa-79046ecf79a9",
        token: "8b3efuxxdtfmmmki457f15f4fh",
        username: "altenwald.com",
        type: "Mattermost",
        metadata: %{
          "channel" => "ytdjgj36s3nyjrxgx3djgdbwoy",
          "base_url" => "https://altenwald.cloud.mattermost.com/api/v4"
        }
      ]
    ]
  ]
]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
