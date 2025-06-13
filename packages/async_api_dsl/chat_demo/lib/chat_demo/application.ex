defmodule ChatDemo.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChatDemoWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ChatDemo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ChatDemoWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end