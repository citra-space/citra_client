defmodule CitraClient.Generated do
  @moduledoc """
  Compile-time entry point for the generated API client.

  On every compile, the OpenAPI schema for the selected target is fetched,
  cached to `priv/openapi.{dev,prod}.json`, and used to metaprogram:

    * one struct module per component schema under `CitraClient.Schemas.*`
    * one operations module per tag under `CitraClient.*`
      (e.g. `CitraClient.GroundStations`)

  ## Selecting a compile target

  The generator reads `CITRA_CLIENT_COMPILE_ENV`:

    * `dev` (default) — fetches from `https://dev.api.citra.space/openapi.json`.
      Dev is a superset of prod, so bindings compiled from it will work for
      every shared endpoint on either environment.
    * `prod` — fetches from `https://api.citra.space/openapi.json` to pin
      bindings to the stable prod schema. Dev-only endpoints are not
      generated.

  Independently, `CITRA_CLIENT_SPEC_URL` overrides the fetch URL entirely
  (for testing against a staging host), and `CITRA_CLIENT_SPEC_PATH` skips
  the network and loads a local JSON file.

  Note that the *runtime* `:env` setting (`CitraClient.set_env/1`) selects
  which base URL to send requests to — it is independent of the compile
  target. Bindings compiled from dev can be used against prod at runtime
  for the 133 shared operations.

  To force a refresh after the API changes, either delete the relevant
  cache file under `priv/` or run `mix clean` before rebuilding.
  """

  {compile_env, spec_url} = CitraClient.OpenAPI.compile_target()

  @compile_env compile_env
  @spec_url spec_url

  @cache_path Path.expand("../../priv/openapi.#{compile_env}.json", __DIR__)

  # Recompile if the cached spec changes on disk.
  if File.exists?(@cache_path), do: @external_resource(@cache_path)

  @spec_data CitraClient.OpenAPI.fetch_spec!(@spec_url, @cache_path)

  :ok = CitraClient.Generator.build_all!(@spec_data)

  @doc "The environment (`:dev` or `:prod`) whose schema the client was compiled against."
  @spec compile_env() :: :dev | :prod
  def compile_env, do: unquote(@compile_env)

  @doc "The URL the spec was fetched from at compile time."
  @spec spec_url() :: String.t()
  def spec_url, do: unquote(@spec_url)

  @doc "Absolute path to the cached OpenAPI JSON on disk."
  @spec cache_path() :: String.t()
  def cache_path, do: unquote(@cache_path)

  @doc "The raw parsed OpenAPI spec used to build the client (for introspection)."
  @spec spec() :: map()
  def spec, do: unquote(Macro.escape(@spec_data))
end
