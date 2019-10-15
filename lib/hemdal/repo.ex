defmodule Hemdal.Repo do
  use Ecto.Repo,
    otp_app: :hemdal,
    adapter: Ecto.Adapters.Postgres
end
