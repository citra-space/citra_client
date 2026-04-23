defmodule CitraClient.OpenAPI do
  @moduledoc false

  # Compile-time helpers for generating bindings from an OpenAPI 3.1 spec.
  # Not intended for runtime use.

  @spec dev_spec_url() :: String.t()
  def dev_spec_url, do: "https://dev.api.citra.space/openapi.json"

  @spec prod_spec_url() :: String.t()
  def prod_spec_url, do: "https://api.citra.space/openapi.json"

  @spec default_spec_url() :: String.t()
  def default_spec_url, do: dev_spec_url()

  # Resolved at compile time of this module against the consumer's config.
  # Elixir records a dependency on :citra_client/:compile_env, so changing
  # the config later triggers a rebuild warning.
  @configured_env (case Application.compile_env(:citra_client, :compile_env, :dev) do
                     e when e in [:dev, :prod] ->
                       e

                     other ->
                       raise "config :citra_client, :compile_env must be :dev or :prod " <>
                               "(got #{inspect(other)})"
                   end)

  @doc """
  Resolves the compile target, returning `{env_atom, url}`.

  Precedence (highest first):

    1. `CITRA_CLIENT_COMPILE_ENV` env var (`"dev"` or `"prod"`)
    2. `config :citra_client, :compile_env, :dev | :prod` (via
       `Application.compile_env/3`, recorded as a compile-time
       dependency so a config change triggers a rebuild warning)
    3. Default: `:dev` (the superset of endpoints)

  `CITRA_CLIENT_SPEC_URL` independently overrides the URL, leaving
  the env atom reflecting the selected target.
  """
  @spec compile_target() :: {:dev | :prod, String.t()}
  def compile_target do
    env =
      case System.get_env("CITRA_CLIENT_COMPILE_ENV") do
        "prod" -> :prod
        "dev" -> :dev
        nil -> @configured_env
        other -> raise "CITRA_CLIENT_COMPILE_ENV must be 'dev' or 'prod' (got #{inspect(other)})"
      end

    url =
      System.get_env("CITRA_CLIENT_SPEC_URL") ||
        case env do
          :prod -> prod_spec_url()
          :dev -> dev_spec_url()
        end

    {env, url}
  end

  @spec fetch_spec!(String.t(), Path.t()) :: map()
  def fetch_spec!(url, cache_path) do
    body =
      case System.get_env("CITRA_CLIENT_SPEC_PATH") do
        nil -> fetch_live_or_cache!(url, cache_path)
        path -> File.read!(path)
      end

    Jason.decode!(body)
  end

  defp fetch_live_or_cache!(url, cache_path) do
    case do_fetch(url) do
      {:ok, body} ->
        File.mkdir_p!(Path.dirname(cache_path))
        File.write!(cache_path, body)
        body

      {:error, reason} ->
        if File.exists?(cache_path) do
          IO.warn(
            "[citra_client] live OpenAPI fetch from #{url} failed (#{reason}); " <>
              "falling back to cache at #{cache_path}"
          )

          File.read!(cache_path)
        else
          raise "citra_client: unable to fetch OpenAPI spec from #{url} (#{reason}) " <>
                  "and no cache exists at #{cache_path}. Set CITRA_CLIENT_SPEC_PATH to a " <>
                  "local JSON file to build offline."
        end
    end
  end

  defp do_fetch(url) do
    # Req needs its own application (and Finch) started to use the default
    # adapter at compile time.
    {:ok, _} = Application.ensure_all_started(:req)

    try do
      case Req.request(method: :get, url: url, decode_body: false, retry: false) do
        {:ok, %{status: 200, body: body}} when is_binary(body) ->
          {:ok, body}

        {:ok, %{status: code, body: body}} ->
          {:error, "HTTP #{code}: #{String.slice(to_string(body), 0, 200)}"}

        {:error, reason} ->
          {:error, inspect(reason)}
      end
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  # -- Name utilities ------------------------------------------------------

  @doc """
  Derive an Elixir function name (snake_case atom-ish string) from a FastAPI
  operationId + path + method. FastAPI encodes the path and method as a suffix
  of the operationId; we strip it to recover the Python function name.
  """
  @spec function_name(String.t(), String.t(), String.t()) :: atom()
  def function_name(operation_id, path, method) do
    suffix = path_slug(path) <> "_" <> String.downcase(method)

    name =
      if String.ends_with?(operation_id, suffix) do
        String.slice(operation_id, 0, byte_size(operation_id) - byte_size(suffix))
      else
        operation_id
      end

    String.to_atom(name)
  end

  defp path_slug(path) do
    path
    |> String.replace(~r/[\/{}\-]/, "_")
  end

  @doc """
  Convert a tag name (e.g. "ground_stations", "caf-results") to a module name
  atom like `CitraClient.GroundStations`.
  """
  @spec tag_module(String.t()) :: module()
  def tag_module(tag) do
    suffix =
      tag
      |> String.split(~r/[-_]/, trim: true)
      |> Enum.map(&capitalize/1)
      |> Enum.join()

    Module.concat([CitraClient, suffix])
  end

  @doc """
  Convert a components.schemas key (e.g. "Antenna", "Elset-Output",
  "AntennaCreateList") to a module name under `CitraClient.Schemas`.
  """
  @spec schema_module(String.t()) :: module()
  def schema_module(name) do
    suffix =
      name
      |> String.split(~r/[-_]/, trim: true)
      |> Enum.map(&capitalize/1)
      |> Enum.join()

    Module.concat([CitraClient.Schemas, suffix])
  end

  defp capitalize(""), do: ""
  defp capitalize(<<first, rest::binary>>), do: <<first>> |> String.upcase() |> Kernel.<>(rest)

  @doc """
  Convert a camelCase or PascalCase string to snake_case.
  Handles runs of uppercase (e.g. "AWSAccessKeyId" -> "aws_access_key_id").
  """
  @spec snake_case(String.t()) :: String.t()
  def snake_case(name) do
    name
    |> String.replace(~r/([a-z0-9])([A-Z])/, "\\1_\\2")
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
    |> String.downcase()
  end

  @doc "Extract ordered path-parameter names from a path template like '/x/{a}/y/{b}'."
  @spec path_params(String.t()) :: [String.t()]
  def path_params(path) do
    Regex.scan(~r/\{([^}]+)\}/, path, capture: :all_but_first)
    |> Enum.map(&hd/1)
  end

  # -- Schema walking ------------------------------------------------------

  @doc """
  Resolve a $ref string like "#/components/schemas/Antenna" to the schema name.
  Returns nil for non-local refs.
  """
  @spec ref_name(String.t()) :: String.t() | nil
  def ref_name("#/components/schemas/" <> name), do: name
  def ref_name(_), do: nil

  @doc """
  Given a schema fragment, strip any `{type: "null"}` branch from an `anyOf`
  and return `{inner_schema, nullable?}`. Recognizes OpenAPI 3.1's nullable
  convention.
  """
  @spec unnull(map()) :: {map(), boolean()}
  def unnull(%{"anyOf" => branches} = schema) do
    {nulls, non_nulls} = Enum.split_with(branches, &null_branch?/1)

    case non_nulls do
      [single] ->
        merged = single |> Map.merge(Map.drop(schema, ["anyOf"]))
        {merged, nulls != []}

      _ ->
        {schema, false}
    end
  end

  def unnull(schema), do: {schema, false}

  defp null_branch?(%{"type" => "null"}), do: true
  defp null_branch?(_), do: false

  @doc """
  Given a schema fragment, return a classification tag used by the code generators:

    * `{:ref, "Name"}` — reference to a named component schema
    * `:datetime`, `:date`, `:uuid`, `:string`, `:integer`, `:number`, `:boolean`
    * `{:array, inner_kind}`
    * `:object` — free-form map
    * `:any` — fallback
  """
  @spec classify(map()) :: any()
  def classify(schema) do
    {schema, _nullable} = unnull(schema || %{})

    cond do
      is_binary(schema["$ref"]) ->
        case ref_name(schema["$ref"]) do
          nil -> :any
          name -> {:ref, name}
        end

      schema["type"] == "array" ->
        {:array, classify(schema["items"] || %{})}

      schema["type"] == "string" and schema["format"] == "date-time" ->
        :datetime

      schema["type"] == "string" and schema["format"] == "date" ->
        :date

      schema["type"] == "string" and schema["format"] == "uuid" ->
        :uuid

      schema["type"] == "string" ->
        :string

      schema["type"] == "integer" ->
        :integer

      schema["type"] == "number" ->
        :number

      schema["type"] == "boolean" ->
        :boolean

      schema["type"] == "object" or is_map(schema["properties"]) ->
        :object

      true ->
        :any
    end
  end

  # -- Runtime decode/encode (compiled into every schema module) -----------

  @doc "Decode a value received from the API based on its classified kind."
  @spec decode_value(any(), any()) :: any()
  def decode_value(nil, _kind), do: nil

  def decode_value(value, :datetime) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> dt
      _ -> value
    end
  end

  def decode_value(value, :date) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, d} -> d
      _ -> value
    end
  end

  def decode_value(value, {:array, inner}) when is_list(value) do
    Enum.map(value, &decode_value(&1, inner))
  end

  def decode_value(value, {:ref, name}) when is_map(value) do
    mod = schema_module(name)

    if Code.ensure_loaded?(mod) and function_exported?(mod, :from_api, 1) do
      mod.from_api(value)
    else
      value
    end
  end

  def decode_value(value, _kind), do: value

  @doc "Encode a value to send to the API based on its classified kind."
  @spec encode_value(any(), any()) :: any()
  def encode_value(nil, _kind), do: nil

  def encode_value(%DateTime{} = dt, _kind), do: DateTime.to_iso8601(dt)
  def encode_value(%Date{} = d, _kind), do: Date.to_iso8601(d)

  def encode_value(value, {:array, inner}) when is_list(value) do
    Enum.map(value, &encode_value(&1, inner))
  end

  def encode_value(%_{} = struct, {:ref, _name}) do
    mod = struct.__struct__

    if function_exported?(mod, :to_api, 1) do
      mod.to_api(struct)
    else
      Map.from_struct(struct)
    end
  end

  def encode_value(value, _kind), do: value
end
