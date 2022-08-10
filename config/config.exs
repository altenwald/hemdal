# this configuration is intended for testing purposes
import Config

config :hemdal,
  log_all_events: false,
  config_module: Hemdal.Config.Backend.Env

config :hemdal, Hemdal.Config, [
  [
    id: "aea48656-be08-4576-a2d0-2723458faefd",
    name: "valid alert check",
    host: [
      id: "2a8572d4-ceb3-4200-8b29-dd1f21b50e54",
      type: "Local",
      name: "127.0.0.1",
      max_workers: 1
    ],
    command: [
      id: "c5c090b2-7b6a-487e-87b8-57788bffaffe",
      name: "get ok status",
      command_type: "line",
      command: "echo '[\"OK\", \"valid one!\"]'"
    ],
    group: [
      id: "35945f03-a691-46e6-b3dd-07c07c513be0",
      name: "Testing"
    ],
    check_in_sec: 60,
    recheck_in_sec: 1,
    broken_recheck_in_sec: 10,
    retries: 1
  ],
  [
    id: "6b6d247c-48c3-4a8c-9b4f-773f178ddc0f",
    name: "invalid alert check",
    host: [
      id: "fd1393bf-c554-45fe-869a-d253466da8ea",
      type: "Local",
      name: "127.0.0.1",
      max_workers: 1
    ],
    command: [
      id: "6b07ea20-f677-44bc-90f4-e07b611068f3",
      name: "get failed status",
      command_type: "line",
      command: "echo '[\"FAIL\", \"invalid one!\"]'"
    ],
    group: [
      id: "35945f03-a691-46e6-b3dd-07c07c513be0",
      name: "Testing"
    ],
    check_in_sec: 60,
    recheck_in_sec: 1,
    broken_recheck_in_sec: 10,
    retries: 1
  ]
]

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"
