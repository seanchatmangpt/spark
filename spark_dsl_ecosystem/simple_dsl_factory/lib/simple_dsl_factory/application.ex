defmodule SimpleDslFactory.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SimpleDslFactory.Repo
    ]

    opts = [strategy: :one_for_one, name: SimpleDslFactory.Supervisor]
    Supervisor.start_link(children, opts)
  end
end