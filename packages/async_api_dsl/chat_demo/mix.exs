defmodule ChatDemo.MixProject do
  use Mix.Project

  def project do
    [
      app: :chat_demo,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {ChatDemo.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.0"},
      {:jason, "~> 1.4"},
      {:plug_cowboy, "~> 2.5"},
      {:websockex, "~> 0.4.3"}
    ]
  end
end