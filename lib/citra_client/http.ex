defmodule CitraClient.HTTP do
  @moduledoc false

  @type call_opts :: [
          method: :get | :post | :put | :patch | :delete,
          path: String.t(),
          query: keyword() | map(),
          body: any(),
          success: [pos_integer()],
          decoder: (any() -> any())
        ]

  @spec call(call_opts()) :: :ok | {:ok, any()} | {:error, {pos_integer(), any()}}
  def call(opts) do
    method = Keyword.fetch!(opts, :method)
    path = Keyword.fetch!(opts, :path)
    success = Keyword.get(opts, :success, [200, 201, 204])
    decoder = Keyword.get(opts, :decoder, & &1)

    req =
      [
        method: method,
        url: CitraClient.base_url() <> String.trim_leading(path, "/"),
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      ]
      |> put_if(:params, normalize_query(Keyword.get(opts, :query)))
      |> put_if(:json, Keyword.get(opts, :body))

    resp = Req.request!(req)

    cond do
      resp.status == 204 -> :ok
      resp.status in success -> {:ok, decoder.(resp.body)}
      true -> {:error, {resp.status, resp.body}}
    end
  end

  defp put_if(kw, _key, nil), do: kw
  defp put_if(kw, _key, []), do: kw
  defp put_if(kw, key, v), do: Keyword.put(kw, key, v)

  @doc false
  def normalize_query(nil), do: nil

  def normalize_query(query) do
    query
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> {k, encode_param(v)} end)
    |> case do
      [] -> nil
      list -> list
    end
  end

  @doc false
  def encode_param(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def encode_param(%Date{} = d), do: Date.to_iso8601(d)
  def encode_param(list) when is_list(list), do: Enum.map(list, &encode_param/1)
  def encode_param(v), do: v
end
