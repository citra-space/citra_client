defmodule CitraClient do
  @moduledoc """
  API client for the Citra Space platform.
  """

  @base_url "https://dev.api.citra.space/"

  alias CitraClient.Entities.Groundstation
  require Logger

  def set_token(token) do
    Application.put_env(:citra_client, :api_token, token)
  end

  @spec get_groundstations() :: [Groundstation.t()]
  @doc """
  Fetches all groundstations on the platform
  """
  @spec get_groundstations() :: [Groundstation.t()]
  def get_groundstations do
    Req.get!(
      @base_url <> "ground-stations",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body["groundStations"]
    |> Enum.map(&map_groundstation/1)
  end

  @doc """
  Gets all groundstations for the authenticated user
  """
  @spec get_my_groundstations() :: [Groundstation.t()]
  def get_my_groundstations do
    Req.get!(
      @base_url <> "my/ground-stations",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body["groundStations"]
    |> Enum.map(&map_groundstation/1)
  end

  @doc """
  Get a specific groundstation by ID
  """
  @spec get_groundstation(String.t()) :: {:ok, Groundstation.t()} | {:error, any()}
  def get_groundstation(id) do
    resp =
      Req.get!(
        @base_url <> "ground-stations/#{id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> {:ok, map_groundstation(resp.body)}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Creates a new groundstation on the platform - returns the UUID of the created groundstation
  """
  @spec create_groundstation(any()) :: {:error, any()} | {:ok, String.t()}
  def create_groundstation(groundstation) do
    body = %{
      "latitude" => groundstation.latitude,
      "longitude" => groundstation.longitude,
      "altitude" => groundstation.altitude,
      "name" => groundstation.name
    }

    resp =
      Req.post!(
        @base_url <> "ground-stations",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      201 -> {:ok, resp.body["id"]}
      _ -> {:error, resp.body}
    end
  end

  def update_groundstation(groundstation) do
    body = %{
      "latitude" => groundstation.latitude,
      "longitude" => groundstation.longitude,
      "altitude" => groundstation.altitude,
      "name" => groundstation.name
    }

    resp =
      Req.put!(
        @base_url <> "ground-stations/#{groundstation.id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      200 -> :ok
      _ -> {:error, resp.body}
    end
  end

  defp map_groundstation(data) do
    {:ok, created_at, _} = DateTime.from_iso8601(data["creationEpoch"])

    # updated_at can be nil
    updated_at =
      if data["updateEpoch"] do
        {:ok, dt, _} = DateTime.from_iso8601(data["updateEpoch"])
        dt
      else
        nil
      end

    %Groundstation{
      latitude: data["latitude"],
      longitude: data["longitude"],
      altitude: data["altitude"],
      id: data["id"],
      user_id: data["userId"],
      creation_epoch: created_at,
      update_epoch: updated_at,
      name: data["name"]
    }
  end

  @spec get_telescopes([String.t()]) :: [CitraClient.Entities.Telescope.t()]
  def get_telescopes(ids) when is_list(ids) do
    Req.get!(
      @base_url <> "telescopes",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)},
      params: %{ids: Enum.join(ids, ",")}
    ).body
    |> Enum.map(&map_telescope/1)
  end

  @spec get_telescopes(String.t()) :: CitraClient.Entities.Telescope.t()
  def get_telescopes(id) do
    get_telescopes([id])
  end

  @spec get_telescopes() :: [CitraClient.Entities.Telescope.t()]
  def get_telescopes() do
    Req.get!(
      @base_url <> "telescopes",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body
    |> Enum.map(&map_telescope/1)
  end

  @spec get_telescopes_by_groundstation(String.t()) :: [CitraClient.Entities.Telescope.t()]
  def get_telescopes_by_groundstation(groundstation_id) do
    Req.get!(
      @base_url <> "ground-stations/#{groundstation_id}/telescopes",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body
    |> Enum.map(&map_telescope/1)
  end

  defp map_telescope(data) do
    {:ok, created_at, _} = DateTime.from_iso8601(data["creationEpoch"])

    # last_connection_epoch can be nil
    last_connection_at =
      if data["lastConnectionEpoch"] do
        {:ok, dt, _} = DateTime.from_iso8601(data["lastConnectionEpoch"])
        dt
      else
        nil
      end

    %CitraClient.Entities.Telescope{
      id: data["id"],
      user_id: data["userId"],
      groundstation_id: data["groundStationId"],
      satellite_id: data["satelliteId"],
      creation_epoch: created_at,
      last_connection_epoch: last_connection_at,
      name: data["name"],
      angular_noise: data["angularNoise"],
      field_of_view: data["fieldOfView"],
      max_magnitude: data["maxMagnitude"],
      min_elevation: data["minElevation"],
      max_slew_rate: data["maxSlewRate"],
      home_azimuth: data["homeAzimuth"],
      home_elevation: data["homeElevation"]
    }
  end

  @doc """
  Creates one or more telescopes on the platform - returns a list of UUIDs of the created telescopes
  """
  @spec create_telescopes([CitraClient.Entities.Telescope.t()]) ::
          {:ok, [String.t()]} | {:error, any()}
  def create_telescopes(telescopes) do
    body = [
      Enum.map(telescopes, fn t ->
        %{
          "name" => t.name,
          "groundStationId" => t.groundstation_id,
          "angularNoise" => t.angular_noise,
          "fieldOfView" => t.field_of_view,
          "maxMagnitude" => t.max_magnitude,
          "minElevation" => t.min_elevation,
          "maxSlewRate" => t.max_slew_rate,
          "homeAzimuth" => t.home_azimuth,
          "homeElevation" => t.home_elevation
        }
      end)
    ]

    resp =
      Req.post!(
        @base_url <> "telescopes",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      201 -> {:ok, resp.body}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Updates one or more telescopes on the platform - returns :ok on success
  """
  @spec update_telescopes([CitraClient.Entities.Telescope.t()]) :: :ok | {:error, any()}
  def update_telescopes(telescopes) do
    body = Enum.map(telescopes, fn t ->
      %{
        "id" => t.id,
        "name" => t.name,
        "groundStationId" => t.groundstation_id,
        "angularNoise" => t.angular_noise,
        "fieldOfView" => t.field_of_view,
        "maxMagnitude" => t.max_magnitude,
        "minElevation" => t.min_elevation,
        "maxSlewRate" => t.max_slew_rate,
        "homeAzimuth" => t.home_azimuth,
        "homeElevation" => t.home_elevation
      }
    end)

    resp =
      Req.put!(
        @base_url <> "telescopes",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      200 -> :ok
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Updates a single telescope on the platform - returns :ok on success
  """
  @spec update_telescope(CitraClient.Entities.Telescope.t()) :: :ok | {:error, any()}
  def update_telescope(telescope) do
    update_telescopes([telescope])
  end

  @doc """
  Creates a new telescope on the platform - returns the UUID of the created telescope
  """
  @spec create_telescope(CitraClient.Entities.Telescope.t()) ::
          {:ok, String.t()} | {:error, any()}
  def create_telescope(telescope) do
    body = [
      %{
        "name" => telescope.name,
        "groundStationId" => telescope.groundstation_id,
        "angularNoise" => telescope.angular_noise,
        "fieldOfView" => telescope.field_of_view,
        "maxMagnitude" => telescope.max_magnitude,
        "minElevation" => telescope.min_elevation,
        "maxSlewRate" => telescope.max_slew_rate,
        "homeAzimuth" => telescope.home_azimuth,
        "homeElevation" => telescope.home_elevation
      }
    ]

    resp =
      Req.post!(
        @base_url <> "telescopes",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      201 -> {:ok, Enum.at(resp.body, 0)}
      _ -> {:error, resp.body}
    end
  end

  @spec create_task(CitraClient.Entities.Task.t()) :: {:ok, String.t()} | {:error, any()}
  def create_task(task) do
    body = %{
      "taskStart" => DateTime.to_iso8601(task.task_start),
      "taskStop" => DateTime.to_iso8601(task.task_end),
      "satelliteId" => task.satellite_id,
      "telescopeId" => task.telescope_id
    }

    resp =
      Req.post!(
        @base_url <> "tasks",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      201 -> {:ok, resp.body["id"]}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Fetches tasks for a given telescope, with optional filtering by start and stop times
  """
  @spec get_tasks(integer()) :: [CitraClient.Entities.Task.t()]
  def get_tasks(telescope_id, opts \\ []) do
    task_start_after =
      Keyword.get(opts, :task_start_after, nil)
      |> case do
        nil -> nil
        dt -> DateTime.to_iso8601(dt)
      end

    task_start_before =
      Keyword.get(opts, :task_start_before, nil)
      |> case do
        nil -> nil
        dt -> DateTime.to_iso8601(dt)
      end

    task_stop_after =
      Keyword.get(opts, :task_stop_after, nil)
      |> case do
        nil -> nil
        dt -> DateTime.to_iso8601(dt)
      end

    task_stop_before =
      Keyword.get(opts, :task_stop_before, nil)
      |> case do
        nil -> nil
        dt -> DateTime.to_iso8601(dt)
      end

    params =
      %{
        "taskStartAfter" => task_start_after,
        "taskStartBefore" => task_start_before,
        "taskStopAfter" => task_stop_after,
        "taskStopBefore" => task_stop_before
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})

    resp =
      Req.get!(
        @base_url <> "telescopes/#{telescope_id}/tasks",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 ->
        Enum.map(resp.body, fn data ->
          {:ok, task_start, _} = DateTime.from_iso8601(data["taskStart"])
          {:ok, task_end, _} = DateTime.from_iso8601(data["taskStop"])

          %CitraClient.Entities.Task{
            id: data["id"],
            task_start: task_start,
            task_end: task_end,
            satellite_id: data["satelliteId"],
            telescope_id: data["telescopeId"],
            status: String.to_existing_atom(String.downcase(data["status"]))
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Updates the status of a given task
  """
  @spec update_task(String.t(), CitraClient.Entities.TaskStatus.t()) :: :ok | {:error, any()}
  def update_task(task_id, status) do
    body = %{
      "status" => CitraClient.Entities.TaskStatus.to_string(status)
    }

    resp =
      Req.put!(
        @base_url <> "tasks/#{task_id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      200 -> :ok
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Gets image upload parameters for a given telescope and image filename - returns AWS S3 upload parameters
  """
  @spec get_image_upload_params(String.t(), String.t()) ::
          {:ok, CitraClient.Entities.ImageUploadParams.t()} | {:error, any()}
  def get_image_upload_params(telescope_id, image_filename) do
    request_params = %{
      "telescope_id" => telescope_id,
      "filename" => image_filename
    }

    resp =
      Req.post!(
        @base_url <> "my/images?" <> URI.encode_query(request_params),
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 ->
        {:ok,
         %CitraClient.Entities.ImageUploadParams{
           aws_access_key_id: resp.body["fields"]["AWSAccessKeyId"],
           content_type: resp.body["fields"]["Content-Type"],
           key: resp.body["fields"]["key"],
           policy: resp.body["fields"]["policy"],
           signature: resp.body["fields"]["signature"],
           filename: resp.body["filename"],
           results_url: resp.body["resultsUrl"],
           upload_url: resp.body["uploadUrl"],
           upload_id: resp.body["uploadId"]
         }}

      _ ->
        {:error, resp.body}
    end
  end

  @doc """
  Uploads an image to S3 using presigned upload parameters obtained from the Citra API
  """
  @spec upload_image_to_s3(String.t(), String.t()) ::
          :ok | {:error, %{body: any(), status: integer(), url: String.t()}}
  def upload_image_to_s3(telescope_id, file_path) do
    # get image filename from file path
    filename = Path.basename(file_path)

    # Get the presigned upload parameters
    {:ok, upload_params} = get_image_upload_params(telescope_id, filename)

    Logger.debug("Uploading file: #{filename}")
    Logger.debug("URL: #{upload_params.upload_url}")

    # Read binary file content for upload
    file_content = File.read!(file_path)

    # AWS is picky about multipart uploads- build the multipart form data manually

    # Create boundary for multipart form
    boundary = "------------------------#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"

    # Create form data manually with binary-safe handling
    body =
      ""
      |> append_part(boundary, "Content-Type", upload_params.content_type)
      |> append_part(boundary, "x-amz-server-side-encryption", "AES256")
      |> append_part(boundary, "key", upload_params.key)
      |> append_part(boundary, "AWSAccessKeyId", upload_params.aws_access_key_id)
      |> append_part(boundary, "policy", upload_params.policy)
      |> append_part(boundary, "signature", upload_params.signature)
      |> append_file(boundary, "file", filename, upload_params.content_type, file_content)
      |> Kernel.<>("--#{boundary}--\r\n")

    # Set Content-Type header with the boundary
    headers = [
      {"Content-Type", "multipart/form-data; boundary=#{boundary}"}
    ]

    resp =
      Req.post!(
        upload_params.upload_url,
        headers: headers,
        body: body
      )

    case resp.status do
      status when status in [200, 204] ->
        Logger.info("Uploaded image #{filename} successfully")
        :ok

      _ ->
        Logger.error("Upload failed for image #{filename} with status: #{resp.status}")
        {:error, %{body: resp.body, status: resp.status, url: upload_params.upload_url}}
    end
  end

  # Helper functions for multipart form construction
  defp append_part(body, boundary, name, value) do
    body <>
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"\r\n\r\n#{value}\r\n"
  end

  defp append_file(body, boundary, name, filename, content_type, data) do
    body <>
      "--#{boundary}\r\nContent-Disposition: form-data; name=\"#{name}\"; filename=\"#{filename}\"\r\nContent-Type: #{content_type}\r\n\r\n" <>
      data <> "\r\n"
  end
end
