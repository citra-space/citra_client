defmodule CitraClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :citra_client,
      version: "0.3.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Elixir client for the Citra Space API",
      package: package(),
      deps: deps(),
      source_url: "https://github.com/citra-space/citra_client",
      homepage_url: "https://github.com/citra-space/citra_client",
      docs: docs()
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
      files: ~w(lib priv .formatter.exs mix.exs README.md LICENSE),
      maintainers: ["jmcguigs"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md": [title: "Overview"]],
      api_reference: true,
      source_ref: "v0.3.0",
      groups_for_modules: [
        "Operations": [~r/^CitraClient\.(?!Schemas|Generated|Generator|HTTP|OpenAPI)[A-Z]/],
        "Schemas": [~r/^CitraClient\.Schemas\./],
        "Internal": [CitraClient.Generated]
      ],
      nest_modules_by_prefix: [CitraClient.Schemas]
    ]
  end
end
