defmodule GSheet.MixProject do
  use Mix.Project

  def project do
    [
      app: :gsheet,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {GSheet.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:goth, "~> 1.2"},
      {:req, "~> 0.5"}
    ]
  end
end
