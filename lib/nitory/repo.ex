defmodule Nitory.Repo do
  use Ecto.Repo,
    otp_app: :nitory,
    adapter: Ecto.Adapters.SQLite3
end
