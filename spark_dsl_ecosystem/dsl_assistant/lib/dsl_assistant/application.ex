defmodule DslAssistant.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DslAssistant.Repo
    ]

    opts = [strategy: :one_for_one, name: DslAssistant.Supervisor]
    Supervisor.start_link(children, opts)
  end
end