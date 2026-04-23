defmodule CitraClient do
  @moduledoc """
  Elixir client for the Citra Space API.

  All API bindings are generated at compile time from the live OpenAPI spec
  at [https://dev.api.citra.space/openapi.json](https://dev.api.citra.space/openapi.json).
  See `CitraClient.Generated` for details on the compile-time fetch, and the
  per-tag modules (e.g. `CitraClient.GroundStations`, `CitraClient.Telescopes`,
  `CitraClient.Antennas`, `CitraClient.Satellites`) for the operations.

  ## Configuration

      config :citra_client, :env, :dev   # or :prod
      config :citra_client, :api_token, "..."

  Or at runtime:

      CitraClient.set_env(:prod)
      CitraClient.set_token(System.get_env("CITRA_PAT"))

  ## Usage

      iex> CitraClient.set_token(System.get_env("CITRA_PAT"))
      iex> {:ok, stations} = CitraClient.GroundStations.get_ground_stations()
      iex> Enum.map(stations, & &1.name)

  The S3 image upload flow (`upload_image_to_s3/2`) is hand-written because
  the final `PUT` hits AWS directly, outside the API surface described by
  the OpenAPI spec.
  """

  require Logger

  @dev_url "https://dev.api.citra.space/"
  @prod_url "https://api.citra.space/"

  @doc "Sets the API environment to `:dev` or `:prod`."
  @spec set_env(:dev | :prod) :: :ok
  def set_env(env) when env in [:dev, :prod] do
    Application.put_env(:citra_client, :env, env)
  end

  @doc "Gets the current API environment. Defaults to `:dev`."
  @spec get_env() :: :dev | :prod
  def get_env, do: Application.get_env(:citra_client, :env, :dev)

  @doc "Returns the base URL for the current environment."
  @spec base_url() :: String.t()
  def base_url do
    case get_env() do
      :prod -> @prod_url
      _ -> @dev_url
    end
  end

  @doc "Stores the Personal Access Token used by all generated API calls."
  @spec set_token(String.t()) :: :ok
  def set_token(token), do: Application.put_env(:citra_client, :api_token, token)

  @doc """
  Uploads an image to S3 using presigned upload parameters obtained from
  `CitraClient.Images.upload_initiate/1` (the generated binding for
  `POST /my/images`). The generated call returns a struct with the
  `uploadUrl`, `fields`, etc.; this helper handles the multipart form POST
  that AWS requires.
  """
  @spec upload_image_to_s3(String.t(), String.t()) ::
          :ok | {:error, %{body: any(), status: integer(), url: String.t()}}
  def upload_image_to_s3(telescope_id, file_path) do
    filename = Path.basename(file_path)

    {:ok, upload_params} =
      CitraClient.Images.upload_initiate(
        telescope_id: telescope_id,
        filename: filename
      )

    Logger.debug("Uploading file: #{filename} to #{upload_params["uploadUrl"]}")

    file_content = File.read!(file_path)
    fields = upload_params["fields"] || %{}
    boundary = "------------------------" <> Base.encode16(:crypto.strong_rand_bytes(8))

    body =
      Enum.reduce(fields, "", fn {k, v}, acc -> append_part(acc, boundary, k, v) end)
      |> append_part(boundary, "x-amz-server-side-encryption", "AES256")
      |> append_file(boundary, "file", filename, fields["Content-Type"], file_content)
      |> Kernel.<>("--" <> boundary <> "--\r\n")

    resp =
      Req.post!(
        upload_params["uploadUrl"],
        headers: [{"Content-Type", "multipart/form-data; boundary=#{boundary}"}],
        body: body
      )

    case resp.status do
      status when status in [200, 204] ->
        Logger.info("Uploaded image #{filename} successfully")
        :ok

      _ ->
        Logger.error("Upload failed for image #{filename} with status: #{resp.status}")
        {:error, %{body: resp.body, status: resp.status, url: upload_params["uploadUrl"]}}
    end
  end

  defp append_part(body, boundary, name, value) do
    body <>
      "--" <>
      boundary <>
      "\r\nContent-Disposition: form-data; name=\"" <> name <> "\"\r\n\r\n" <> to_string(value) <> "\r\n"
  end

  defp append_file(body, boundary, name, filename, content_type, data) do
    body <>
      "--" <>
      boundary <>
      "\r\nContent-Disposition: form-data; name=\"" <>
      name <>
      "\"; filename=\"" <>
      filename <>
      "\"\r\nContent-Type: " <> to_string(content_type) <> "\r\n\r\n" <> data <> "\r\n"
  end
end
