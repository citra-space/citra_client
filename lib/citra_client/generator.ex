defmodule CitraClient.Generator do
  @moduledoc false

  # Compile-time code generator. Reads an OpenAPI 3.1 spec and metaprograms:
  #   * one struct module per object schema under `CitraClient.Schemas.*`
  #   * one operations module per tag under `CitraClient.*`
  # Called from `CitraClient.Generated` once per compile.

  alias CitraClient.OpenAPI

  @spec build_all!(map()) :: :ok
  def build_all!(spec) do
    schemas = spec["components"]["schemas"] || %{}
    paths = spec["paths"] || %{}

    # Pre-compute the set of schema names that will be generated as structs
    # (i.e. schemas with non-empty `properties`). Used when building cross-
    # references in docs to avoid linking to non-existent modules.
    generable =
      for {name, schema_def} <- schemas,
          is_map(schema_def["properties"]) and map_size(schema_def["properties"]) > 0,
          into: MapSet.new() do
        name
      end

    for {name, schema_def} <- schemas do
      build_schema(name, schema_def, generable)
    end

    paths
    |> group_operations_by_tag()
    |> Enum.each(fn {tag, ops} -> build_tag(tag, ops) end)

    :ok
  end

  # -- Schema struct builder ----------------------------------------------

  defp build_schema(name, schema_def, generable) do
    properties = schema_def["properties"]

    if is_map(properties) and map_size(properties) > 0 do
      mod = OpenAPI.schema_module(name)

      fields =
        properties
        |> Enum.map(fn {api_key, prop_schema} ->
          field = String.to_atom(OpenAPI.snake_case(api_key))
          kind = OpenAPI.classify(prop_schema)
          description = prop_schema["description"]
          {field, api_key, kind, description}
        end)
        |> Enum.sort()

      field_atoms = Enum.map(fields, fn {f, _, _, _} -> f end)
      specs = Map.new(fields, fn {f, k, kind, _} -> {f, {k, kind}} end)
      moduledoc = build_schema_moduledoc(name, schema_def, fields, generable)
      type_spec_ast = build_struct_type_spec(field_atoms, fields, generable)

      quoted =
        quote do
          @moduledoc unquote(moduledoc)

          defstruct unquote(field_atoms)

          unquote(type_spec_ast)

          @doc false
          def __specs__, do: unquote(Macro.escape(specs))

          @doc """
          Build this struct from a decoded JSON map received from the API.
          Unknown fields are ignored.
          """
          def from_api(data) when is_map(data) do
            Enum.reduce(__specs__(), %__MODULE__{}, fn {field, {api_key, kind}}, acc ->
              case Map.fetch(data, api_key) do
                {:ok, value} ->
                  Map.put(acc, field, CitraClient.OpenAPI.decode_value(value, kind))

                :error ->
                  acc
              end
            end)
          end

          @doc """
          Convert this struct into a map with the API's camelCase keys, ready
          to be JSON-encoded. Fields whose value is `nil` are omitted.
          """
          def to_api(%__MODULE__{} = struct) do
            Enum.reduce(__specs__(), %{}, fn {field, {api_key, kind}}, acc ->
              case Map.get(struct, field) do
                nil -> acc
                value -> Map.put(acc, api_key, CitraClient.OpenAPI.encode_value(value, kind))
              end
            end)
          end

          def to_api(map) when is_map(map), do: map
        end

      Module.create(mod, quoted, Macro.Env.location(__ENV__))
    end
  end

  defp build_schema_moduledoc(name, schema_def, fields, generable) do
    header =
      case schema_def["description"] do
        nil -> "Struct generated from the `#{name}` schema."
        desc -> String.trim(desc)
      end

    field_lines =
      fields
      |> Enum.map(fn {field, api_key, kind, description} ->
        type_str = type_label(kind, generable)
        desc = if description, do: " — " <> String.trim(description), else: ""

        key_note =
          if Atom.to_string(field) != api_key, do: " (API key: `#{api_key}`)", else: ""

        "  * `:#{field}` — #{type_str}#{key_note}#{desc}"
      end)
      |> Enum.join("\n")

    header <> "\n\n## Fields\n\n" <> field_lines
  end

  defp type_label({:ref, name}, generable) do
    if MapSet.member?(generable, name) do
      mod_name = OpenAPI.schema_module(name) |> inspect()
      "`#{mod_name}.t()`"
    else
      "`#{name}` (see OpenAPI spec)"
    end
  end

  defp type_label({:array, inner}, generable), do: "list of #{type_label(inner, generable)}"
  defp type_label(:datetime, _), do: "`DateTime.t()`"
  defp type_label(:date, _), do: "`Date.t()`"
  defp type_label(:uuid, _), do: "UUID `String.t()`"
  defp type_label(:string, _), do: "`String.t()`"
  defp type_label(:integer, _), do: "`integer()`"
  defp type_label(:number, _), do: "`number()`"
  defp type_label(:boolean, _), do: "`boolean()`"
  defp type_label(:object, _), do: "`map()`"
  defp type_label(_, _), do: "`any()`"

  defp build_struct_type_spec(_field_atoms, fields, generable) do
    type_map =
      Enum.map(fields, fn {field, _api_key, kind, _desc} ->
        {field, kind_to_typespec(kind, generable)}
      end)

    # Build AST: @type t :: %__MODULE__{field1: type1, field2: type2, ...}
    struct_type_ast = {:%, [], [{:__MODULE__, [], nil}, {:%{}, [], type_map}]}

    quote do
      @type t :: unquote(struct_type_ast)
    end
  end

  defp kind_to_typespec(:datetime, _), do: quote(do: DateTime.t() | nil)
  defp kind_to_typespec(:date, _), do: quote(do: Date.t() | nil)
  defp kind_to_typespec(:uuid, _), do: quote(do: String.t() | nil)
  defp kind_to_typespec(:string, _), do: quote(do: String.t() | nil)
  defp kind_to_typespec(:integer, _), do: quote(do: integer() | nil)
  defp kind_to_typespec(:number, _), do: quote(do: number() | nil)
  defp kind_to_typespec(:boolean, _), do: quote(do: boolean() | nil)
  defp kind_to_typespec(:object, _), do: quote(do: map() | nil)

  defp kind_to_typespec({:array, inner}, generable),
    do: quote(do: [unquote(kind_to_typespec(inner, generable))])

  defp kind_to_typespec({:ref, name}, generable) do
    if MapSet.member?(generable, name) do
      mod = OpenAPI.schema_module(name)
      quote do: unquote(mod).t() | map() | nil
    else
      quote do: map() | String.t() | nil
    end
  end

  defp kind_to_typespec(_, _), do: quote(do: any())

  # -- Operation module builder -------------------------------------------

  defp group_operations_by_tag(paths) do
    for {path, methods} <- paths,
        {method, op} <- methods,
        method in ["get", "post", "put", "patch", "delete"],
        reduce: %{} do
      acc ->
        tag = op |> Map.get("tags", ["default"]) |> List.first() || "default"
        Map.update(acc, tag, [{path, method, op}], &(&1 ++ [{path, method, op}]))
    end
  end

  defp build_tag(tag, ops) do
    mod = OpenAPI.tag_module(tag)

    funcs =
      ops
      |> Enum.map(fn {path, method, op} -> build_operation(path, method, op) end)
      |> Enum.reject(&is_nil/1)

    quoted =
      quote do
        @moduledoc unquote("Generated operations for OpenAPI tag `#{tag}`.")
        unquote_splicing(funcs)
      end

    Module.create(mod, quoted, Macro.Env.location(__ENV__))
  end

  defp build_operation(path, method, op) do
    operation_id = op["operationId"] || "#{method}_#{sanitize(path)}"
    func = OpenAPI.function_name(operation_id, path, method)

    summary = op["summary"] || ""
    description = op["description"] || ""

    path_params = OpenAPI.path_params(path)
    path_param_vars = Enum.map(path_params, &Macro.var(String.to_atom(&1), nil))

    query_params = Enum.filter(op["parameters"] || [], &(&1["in"] == "query"))
    has_query = query_params != []

    body_schema = get_in(op, ["requestBody", "content", "application/json", "schema"])
    has_body = is_map(body_schema)

    response_schema = pick_2xx_schema(op["responses"] || %{})
    success = success_codes(op["responses"] || %{})

    path_ast = build_path_ast(path)

    # Assemble function args: path params, then body (if any), then opts (if any query params)
    args = path_param_vars
    args = if has_body, do: args ++ [Macro.var(:body, nil)], else: args

    args =
      if has_query do
        args ++ [{:\\, [], [Macro.var(:opts, nil), []]}]
      else
        args
      end

    # Build the keyword list passed to HTTP.call
    entries = [
      method: String.to_atom(method),
      path: path_ast
    ]

    entries =
      if has_body do
        body_ast = build_body_ast(body_schema)
        entries ++ [body: body_ast]
      else
        entries
      end

    entries =
      if has_query do
        query_ast = build_query_ast(query_params)
        entries ++ [query: query_ast]
      else
        entries
      end

    entries =
      case build_decoder_ast(response_schema) do
        nil -> entries
        decoder_ast -> entries ++ [decoder: decoder_ast]
      end

    entries = entries ++ [success: success]

    doc = build_doc(summary, description, path, method, path_params, query_params, has_body)

    quote do
      @doc unquote(doc)
      def unquote(func)(unquote_splicing(args)) do
        CitraClient.HTTP.call(unquote(entries))
      end
    end
  end

  defp build_path_ast(path) do
    parts = Regex.split(~r/(\{[^}]+\})/, path, include_captures: true, trim: true)

    segments =
      Enum.map(parts, fn
        "{" <> rest ->
          param = String.trim_trailing(rest, "}")
          var = Macro.var(String.to_atom(param), nil)
          quote do: URI.encode(to_string(unquote(var)), &URI.char_unreserved?/1)

        literal ->
          literal
      end)

    case segments do
      [single] ->
        single

      [first | rest] ->
        Enum.reduce(rest, first, fn seg, acc ->
          quote do: unquote(acc) <> unquote(seg)
        end)
    end
  end

  defp build_body_ast(body_schema) do
    kind = OpenAPI.classify(body_schema)
    escaped = Macro.escape(kind)

    quote do
      CitraClient.OpenAPI.encode_value(unquote(Macro.var(:body, nil)), unquote(escaped))
    end
  end

  defp build_query_ast(query_params) do
    opts_var = Macro.var(:opts, nil)

    for p <- query_params do
      api_name = p["name"]
      field_atom = String.to_atom(OpenAPI.snake_case(api_name))
      default = get_in(p, ["schema", "default"])
      default_ast = Macro.escape(default)

      value_ast =
        quote do
          Keyword.get(unquote(opts_var), unquote(field_atom), unquote(default_ast))
        end

      {api_name, value_ast}
    end
  end

  defp build_decoder_ast(nil), do: nil

  defp build_decoder_ast(schema) do
    case OpenAPI.classify(schema) do
      :any -> nil
      :string -> nil
      :integer -> nil
      :number -> nil
      :boolean -> nil
      :object -> nil
      kind ->
        escaped = Macro.escape(kind)

        quote do
          fn data -> CitraClient.OpenAPI.decode_value(data, unquote(escaped)) end
        end
    end
  end

  defp pick_2xx_schema(responses) do
    responses
    |> Enum.filter(fn {code, _} -> String.match?(code, ~r/^2\d\d$/) end)
    |> Enum.sort_by(fn {code, _} -> code end)
    |> Enum.find_value(fn {_code, r} ->
      get_in(r, ["content", "application/json", "schema"])
    end)
  end

  defp success_codes(responses) do
    responses
    |> Map.keys()
    |> Enum.filter(&String.match?(&1, ~r/^2\d\d$/))
    |> Enum.map(&String.to_integer/1)
    |> case do
      [] -> [200, 201, 204]
      codes -> Enum.sort(codes)
    end
  end

  defp build_doc(summary, description, path, method, path_params, query_params, has_body) do
    parts = [
      String.trim(summary),
      String.trim(description),
      "`#{String.upcase(method)} #{path}`"
    ]

    parts =
      if path_params != [] do
        params_doc =
          path_params
          |> Enum.map(&"- `#{OpenAPI.snake_case(&1)}` (path)")
          |> Enum.join("\n")

        parts ++ ["## Path parameters\n\n" <> params_doc]
      else
        parts
      end

    parts =
      if query_params != [] do
        opts_doc =
          query_params
          |> Enum.map(fn p ->
            name = OpenAPI.snake_case(p["name"])
            desc = String.trim(p["description"] || "")
            required = p["required"] || false
            tag = if required, do: " (required)", else: ""
            line = "- `:#{name}`#{tag}"
            if desc == "", do: line, else: "#{line} — #{desc}"
          end)
          |> Enum.join("\n")

        parts ++ ["## Options (passed via keyword list)\n\n" <> opts_doc]
      else
        parts
      end

    parts =
      if has_body do
        parts ++ ["## Body\n\nRequest body (map or generated struct)."]
      else
        parts
      end

    parts
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp sanitize(s), do: String.replace(s, ~r/[^a-zA-Z0-9_]/, "_")
end
