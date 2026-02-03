defmodule CitraClient do
  @moduledoc """
  API client for the Citra Space platform.

  ## Configuration

  Configure the environment in your `config.exs`:

      config :citra_client, :env, :dev   # or :prod

  Or set it at runtime:

      CitraClient.set_env(:prod)

  Available environments:
  - `:dev` - Uses `https://dev.api.citra.space/` (default)
  - `:prod` - Uses `https://api.citra.space/`
  """

  @dev_url "https://dev.api.citra.space/"
  @prod_url "https://api.citra.space/"

  alias CitraClient.Entities.Groundstation
  alias CitraClient.Entities.Telescope
  alias CitraClient.Entities.Task
  alias CitraClient.Entities.ImageUploadParams
  alias CitraClient.Entities.TaskStatus
  alias CitraClient.Entities.Antenna
  alias CitraClient.Entities.Satellite
  require Logger

  @doc """
  Sets the API environment to `:dev` or `:prod`.
  """
  @spec set_env(:dev | :prod) :: :ok
  def set_env(env) when env in [:dev, :prod] do
    Application.put_env(:citra_client, :env, env)
  end

  @doc """
  Gets the current API environment. Defaults to `:dev`.
  """
  @spec get_env() :: :dev | :prod
  def get_env do
    Application.get_env(:citra_client, :env, :dev)
  end

  @doc """
  Returns the base URL for the current environment.
  """
  @spec base_url() :: String.t()
  def base_url do
    case get_env() do
      :prod -> @prod_url
      _ -> @dev_url
    end
  end

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
      base_url() <> "ground-stations",
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
      base_url() <> "my/ground-stations",
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
        base_url() <> "ground-stations/#{id}",
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
        base_url() <> "ground-stations",
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
        base_url() <> "ground-stations/#{groundstation.id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      200 -> :ok
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Deletes a groundstation by ID
  """
  @spec delete_groundstation(String.t()) :: :ok | {:error, any()}
  def delete_groundstation(id) do
    resp =
      Req.delete!(
        base_url() <> "ground-stations/#{id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      204 -> :ok
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

  @spec get_telescopes([String.t()]) :: [Telescope.t()]
  def get_telescopes(ids) when is_list(ids) do
    Req.get!(
      base_url() <> "telescopes",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)},
      params: %{ids: Enum.join(ids, ",")}
    ).body
    |> Enum.map(&map_telescope/1)
  end

  @spec get_telescopes(String.t()) :: Telescope.t()
  def get_telescopes(id) do
    get_telescopes([id])
  end

  @spec get_telescopes() :: [Telescope.t()]
  def get_telescopes() do
    Req.get!(
      base_url() <> "telescopes",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body
    |> Enum.map(&map_telescope/1)
  end

  @spec get_telescopes_by_groundstation(String.t()) :: [Telescope.t()]
  def get_telescopes_by_groundstation(groundstation_id) do
    Req.get!(
      base_url() <> "ground-stations/#{groundstation_id}/telescopes",
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

    %Telescope{
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
    body =
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

    resp =
      Req.post!(
        base_url() <> "telescopes",
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
  @spec update_telescopes([Telescope.t()]) :: :ok | {:error, any()}
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
        base_url() <> "telescopes",
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
  @spec update_telescope(Telescope.t()) :: :ok | {:error, any()}
  def update_telescope(telescope) do
    update_telescopes([telescope])
  end

  @doc """
  Creates a new telescope on the platform - returns the UUID of the created telescope
  """
  @spec create_telescope(Telescope.t()) ::
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
        base_url() <> "telescopes",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      201 -> {:ok, Enum.at(resp.body, 0)}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Deletes one or more telescopes by ID
  """
  @spec delete_telescopes([String.t()]) :: :ok | {:error, any()}
  def delete_telescopes(ids) when is_list(ids) do
    resp =
      Req.delete!(
        base_url() <> "telescopes",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: ids
      )

    case resp.status do
      200 -> :ok
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Deletes a single telescope by ID
  """
  @spec delete_telescope(String.t()) :: :ok | {:error, any()}
  def delete_telescope(id) do
    delete_telescopes([id])
  end

  @doc """
  Gets all telescopes for the authenticated user
  """
  @spec get_my_telescopes() :: [Telescope.t()]
  def get_my_telescopes() do
    Req.get!(
      base_url() <> "my/telescopes",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body
    |> Enum.map(&map_telescope/1)
  end

  @doc """
  Gets images for a specific telescope
  """
  @spec get_telescope_images(String.t(), keyword()) :: [map()]
  def get_telescope_images(telescope_id, opts \\ []) do
    params =
      %{
        "limit" => Keyword.get(opts, :limit),
        "offset" => Keyword.get(opts, :offset)
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})

    resp =
      Req.get!(
        base_url() <> "telescopes/#{telescope_id}/images",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 -> resp.body
      _ -> []
    end
  end

  @spec create_antenna(Antenna.t()) ::
          {:ok, String.t()} | {:error, any()}
  def create_antenna(antenna) do
    body = %{
      "name" => antenna.name,
      "groundStationId" => antenna.ground_station_id,
      "satelliteId" => antenna.satellite_id,
      "minFrequency" => antenna.min_frequency,
      "maxFrequency" => antenna.max_frequency,
      "minElevation" => antenna.min_elevation,
      "maxSlewRate" => antenna.max_slew_rate,
      "homeAzimuth" => antenna.home_azimuth,
      "homeElevation" => antenna.home_elevation,
      "halfPowerBeamWidth" => antenna.half_power_beam_width
    }
    resp =
      Req.post!(
        base_url() <> "antennas",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: [body]
      )

    case resp.status do
      201 ->
        # Response is a list of IDs since we send a list
        {:ok, Enum.at(resp.body, 0)}

      _ ->
        {:error, resp.body}
    end
  end

  defp map_antenna(data) do
    {:ok, creation_epoch, _} = DateTime.from_iso8601(data["creationEpoch"])

    last_connection_epoch =
      if data["lastConnectionEpoch"] do
        {:ok, dt, _} = DateTime.from_iso8601(data["lastConnectionEpoch"])
        dt
      else
        nil
      end

    %Antenna{
      id: data["id"],
      user_id: data["userId"],
      ground_station_id: data["groundStationId"],
      satellite_id: data["satelliteId"],
      user_group_id: data["userGroupId"],
      creation_epoch: creation_epoch,
      username: data["username"],
      last_connection_epoch: last_connection_epoch,
      name: data["name"],
      min_frequency: data["minFrequency"],
      max_frequency: data["maxFrequency"],
      min_elevation: data["minElevation"],
      max_slew_rate: data["maxSlewRate"],
      home_azimuth: data["homeAzimuth"],
      home_elevation: data["homeElevation"],
      half_power_beam_width: data["halfPowerBeamWidth"],
      status: data["status"]
    }
  end

  @spec get_antennas() :: [Antenna.t()]
  def get_antennas() do
    Req.get!(
      base_url() <> "antennas",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body
    |> Enum.map(&map_antenna/1)
  end

  @doc """
  Gets all antennas for the authenticated user
  """
  @spec get_my_antennas() :: [Antenna.t()]
  def get_my_antennas() do
    Req.get!(
      base_url() <> "my/antennas",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body
    |> Enum.map(&map_antenna/1)
  end

  @doc """
  Gets a specific antenna by ID
  """
  @spec get_antenna(String.t()) :: {:ok, Antenna.t()} | {:error, any()}
  def get_antenna(id) do
    resp =
      Req.get!(
        base_url() <> "antennas/#{id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> {:ok, map_antenna(resp.body)}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Deletes one or more antennas by ID
  """
  @spec delete_antennas([String.t()]) :: :ok | {:error, any()}
  def delete_antennas(ids) when is_list(ids) do
    resp =
      Req.delete!(
        base_url() <> "antennas",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: ids
      )

    case resp.status do
      200 -> :ok
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Deletes a single antenna by ID
  """
  @spec delete_antenna(String.t()) :: :ok | {:error, any()}
  def delete_antenna(id) do
    delete_antennas([id])
  end

  @doc """
  Gets antennas for a specific groundstation
  """
  @spec get_antennas_by_groundstation(String.t()) :: [Antenna.t()]
  def get_antennas_by_groundstation(groundstation_id) do
    Req.get!(
      base_url() <> "ground-stations/#{groundstation_id}/antennas",
      auth: {:bearer, Application.get_env(:citra_client, :api_token)}
    ).body
    |> Enum.map(&map_antenna/1)
  end

  @doc """
  Gets tasks for a specific antenna with optional filtering
  """
  @spec get_antenna_tasks(String.t(), keyword()) :: [Task.t()]
  def get_antenna_tasks(antenna_id, opts \\ []) do
    params = build_task_filter_params(opts)

    resp =
      Req.get!(
        base_url() <> "antennas/#{antenna_id}/tasks",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 -> Enum.map(resp.body, &map_task/1)
      _ -> []
    end
  end

  @spec create_task(Task.t()) :: {:ok, String.t()} | {:error, any()}
  def create_task(task) do
    body = %{
      "taskStart" => DateTime.to_iso8601(task.task_start),
      "taskStop" => DateTime.to_iso8601(task.task_end),
      "satelliteId" => task.satellite_id,
      "telescopeId" => task.telescope_id
    }

    resp =
      Req.post!(
        base_url() <> "tasks",
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
  @spec get_tasks(integer()) :: [Task.t()]
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
        base_url() <> "telescopes/#{telescope_id}/tasks",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 ->
        Enum.map(resp.body, fn data ->
          {:ok, task_start, _} = DateTime.from_iso8601(data["taskStart"])
          {:ok, task_end, _} = DateTime.from_iso8601(data["taskStop"])

          %Task{
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
  @spec update_task(String.t(), TaskStatus.t()) :: :ok | {:error, any()}
  def update_task(task_id, status) do
    body = %{
      "status" => TaskStatus.to_string(status)
    }

    resp =
      Req.put!(
        base_url() <> "tasks/#{task_id}",
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
          {:ok, ImageUploadParams.t()} | {:error, any()}
  def get_image_upload_params(telescope_id, image_filename) do
    request_params = %{
      "telescope_id" => telescope_id,
      "filename" => image_filename
    }

    resp =
      Req.post!(
        base_url() <> "my/images?" <> URI.encode_query(request_params),
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 ->
        {:ok,
         %ImageUploadParams{
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

  @spec upload_rf_capture(String.t(), CitraClient.Entities.RfCapture.t()) :: :ok | {:error, any()}
  def upload_rf_capture(antenna_id, rf_capture) do
    body = %{
      "antennaId" => antenna_id,
      "taskId" => rf_capture.task_id,
      "captureStart" => DateTime.to_iso8601(rf_capture.capture_start),
      "captureEnd" => DateTime.to_iso8601(rf_capture.capture_end),
      "data" => %{
        "detections" => Enum.map(rf_capture.data.detections, fn detection ->
          %{
            "centerFrequencyHz" => detection.center_frequency_hz,
            "bandwidthHz" => detection.bandwidth_hz,
            "strengthDbm" => detection.strength_dbm,
            "snrDb" => detection.snr_db
          }
        end),
        "powerSpectralDensity" => %{
          "frequencyHz" => rf_capture.data.power_spectral_density.frequency_hz,
          "powerDbmPerHz" => rf_capture.data.power_spectral_density.power_dbm_per_hz
        }
      }
    }

    resp =
      Req.post!(
        base_url() <> "rf-captures",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        json: body
      )

    case resp.status do
      201 -> :ok
      _ -> {:error, resp.body}
    end
  end

  # Helper function to build task filter params from keyword list
  defp build_task_filter_params(opts) do
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

    %{
      "taskStartAfter" => task_start_after,
      "taskStartBefore" => task_start_before,
      "taskStopAfter" => task_stop_after,
      "taskStopBefore" => task_stop_before
    }
    |> Enum.filter(fn {_k, v} -> v != nil end)
    |> Enum.into(%{})
  end

  # Helper function to map task data to Task struct
  defp map_task(data) do
    {:ok, task_start, _} = DateTime.from_iso8601(data["taskStart"])
    {:ok, task_end, _} = DateTime.from_iso8601(data["taskStop"])

    %Task{
      id: data["id"],
      task_start: task_start,
      task_end: task_end,
      satellite_id: data["satelliteId"],
      telescope_id: data["telescopeId"],
      antenna_id: data["antennaId"],
      status: String.to_existing_atom(String.downcase(data["status"]))
    }
  end

  # ============================================================================
  # Satellite Functions
  # ============================================================================

  @doc """
  Gets paginated list of satellites with optional filtering
  """
  @spec get_satellites(keyword()) :: {:ok, map()} | {:error, any()}
  def get_satellites(opts \\ []) do
    params =
      %{
        "page" => Keyword.get(opts, :page),
        "pageSize" => Keyword.get(opts, :page_size),
        "sort" => Keyword.get(opts, :sort),
        "filters" => Keyword.get(opts, :filters),
        "quickFilter" => Keyword.get(opts, :quick_filter),
        "showDecayed" => Keyword.get(opts, :show_decayed)
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})

    resp =
      Req.get!(
        base_url() <> "satellites",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 -> {:ok, resp.body}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Gets a specific satellite by ID
  """
  @spec get_satellite(String.t()) :: {:ok, Satellite.t()} | {:error, any()}
  def get_satellite(id) do
    resp =
      Req.get!(
        base_url() <> "satellites/#{id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> {:ok, map_satellite(resp.body)}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Gets tasks for a specific satellite
  """
  @spec get_satellite_tasks(String.t(), keyword()) :: [Task.t()]
  def get_satellite_tasks(satellite_id, opts \\ []) do
    params = build_task_filter_params(opts)

    resp =
      Req.get!(
        base_url() <> "satellites/#{satellite_id}/tasks",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 -> Enum.map(resp.body, &map_task/1)
      _ -> []
    end
  end

  @doc """
  Gets images for a specific satellite
  """
  @spec get_satellite_images(String.t(), keyword()) :: [map()]
  def get_satellite_images(satellite_id, opts \\ []) do
    params =
      %{
        "limit" => Keyword.get(opts, :limit),
        "offset" => Keyword.get(opts, :offset)
      }
      |> Enum.filter(fn {_k, v} -> v != nil end)
      |> Enum.into(%{})

    resp =
      Req.get!(
        base_url() <> "satellites/#{satellite_id}/images",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 -> resp.body
      _ -> []
    end
  end

  @doc """
  Gets satellite overview statistics
  """
  @spec get_satellites_overview() :: {:ok, map()} | {:error, any()}
  def get_satellites_overview() do
    resp =
      Req.get!(
        base_url() <> "satellites/overview",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> {:ok, resp.body}
      _ -> {:error, resp.body}
    end
  end

  defp map_satellite(data) do
    launch_date =
      if data["launchDate"] do
        case Date.from_iso8601(data["launchDate"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    decay_date =
      if data["decayDate"] do
        case Date.from_iso8601(data["decayDate"]) do
          {:ok, date} -> date
          _ -> nil
        end
      else
        nil
      end

    %Satellite{
      id: data["id"],
      name: data["name"],
      norad_id: data["noradId"],
      cospar_id: data["cosparId"],
      object_type: data["objectType"],
      country: data["country"],
      launch_date: launch_date,
      decay_date: decay_date,
      period: data["period"],
      inclination: data["inclination"],
      apogee: data["apogee"],
      perigee: data["perigee"],
      rcs: data["rcs"],
      data_status: data["dataStatus"],
      orbit_center: data["orbitCenter"],
      orbit_type: data["orbitType"]
    }
  end

  # ============================================================================
  # Image Management Functions
  # ============================================================================

  @doc """
  Gets all images for the authenticated user
  """
  @spec get_my_images() :: [map()]
  def get_my_images() do
    resp =
      Req.get!(
        base_url() <> "my/images",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> resp.body
      _ -> []
    end
  end

  @doc """
  Gets a specific image upload by ID
  """
  @spec get_image(String.t()) :: {:ok, map()} | {:error, any()}
  def get_image(upload_id) do
    resp =
      Req.get!(
        base_url() <> "my/images/#{upload_id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> {:ok, resp.body}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Deletes an image upload by ID
  """
  @spec delete_image(String.t()) :: :ok | {:error, any()}
  def delete_image(upload_id) do
    resp =
      Req.delete!(
        base_url() <> "my/images/#{upload_id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      204 -> :ok
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Gets images for a specific task
  """
  @spec get_task_images(String.t()) :: [map()]
  def get_task_images(task_id) do
    resp =
      Req.get!(
        base_url() <> "tasks/#{task_id}/images",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> resp.body
      _ -> []
    end
  end

  # ============================================================================
  # RF Capture Functions
  # ============================================================================

  @doc """
  Gets a specific RF capture by ID
  """
  @spec get_rf_capture(String.t()) :: {:ok, map()} | {:error, any()}
  def get_rf_capture(capture_id) do
    resp =
      Req.get!(
        base_url() <> "rf-captures/#{capture_id}",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> {:ok, resp.body}
      _ -> {:error, resp.body}
    end
  end

  @doc """
  Gets RF captures for a specific antenna
  """
  @spec get_antenna_rf_captures(String.t()) :: [map()]
  def get_antenna_rf_captures(antenna_id) do
    resp =
      Req.get!(
        base_url() <> "antennas/#{antenna_id}/rf-captures",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> resp.body
      _ -> []
    end
  end

  @doc """
  Gets RF captures for a specific task
  """
  @spec get_task_rf_captures(String.t()) :: [map()]
  def get_task_rf_captures(task_id) do
    resp =
      Req.get!(
        base_url() <> "tasks/#{task_id}/rf-captures",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> resp.body
      _ -> []
    end
  end

  @doc """
  Gets RF captures for a specific satellite
  """
  @spec get_satellite_rf_captures(String.t()) :: [map()]
  def get_satellite_rf_captures(satellite_id) do
    resp =
      Req.get!(
        base_url() <> "satellites/#{satellite_id}/rf-captures",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)}
      )

    case resp.status do
      200 -> resp.body
      _ -> []
    end
  end

  # ============================================================================
  # Weather Functions
  # ============================================================================

  @doc """
  Gets weather data for a specific location
  """
  @spec get_weather(float(), float(), keyword()) :: {:ok, map()} | {:error, any()}
  def get_weather(lat, lon, opts \\ []) do
    params =
      %{
        "lat" => lat,
        "lon" => lon,
        "units" => Keyword.get(opts, :units, "imperial")
      }

    resp =
      Req.get!(
        base_url() <> "weather",
        auth: {:bearer, Application.get_env(:citra_client, :api_token)},
        params: params
      )

    case resp.status do
      200 -> {:ok, resp.body}
      _ -> {:error, resp.body}
    end
  end
end
