defmodule CitraClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :citra_client,
      version: "0.1.4",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Elixir client for the Citra Space API",
      package: package(),
      deps: deps(),
      source_url: "https://github.com/jmcguigs/citra_client",
      homepage_url: "https://github.com/jmcguigs/citra_client",
      docs: [
        main: "CitraClient",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:req, "~> 0.5.4"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/citra-space/citra_client"},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE),
      maintainers: ["jmcguigs"]
    ]
  end
end
