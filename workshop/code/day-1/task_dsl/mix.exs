defmodule TaskDsl.MixProject do
  use Mix.Project

  def project do
    [
      app: :task_dsl,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:spark, "~> 2.2.65"},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: "https://github.com/workshop/task_dsl",
      extras: [
        "README.md"
      ]
    ]
  end

  defp aliases do
    [
      docs: ["spark.cheat_sheets", "docs"],
      test: ["test --color"]
    ]
  end
end