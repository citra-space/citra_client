defmodule CitraClientTest do
  use ExUnit.Case, async: false

  describe "environment configuration" do
    test "set_env/1 and get_env/0 work correctly" do
      CitraClient.set_env(:dev)
      assert CitraClient.get_env() == :dev

      CitraClient.set_env(:prod)
      assert CitraClient.get_env() == :prod

      CitraClient.set_env(:dev)
    end

    test "base_url/0 follows the environment" do
      CitraClient.set_env(:dev)
      assert CitraClient.base_url() == "https://dev.api.citra.space/"

      CitraClient.set_env(:prod)
      assert CitraClient.base_url() == "https://api.citra.space/"

      CitraClient.set_env(:dev)
    end
  end

  describe "generated modules" do
    test "per-tag operation modules were generated" do
      for mod <- [
            CitraClient.GroundStations,
            CitraClient.Telescopes,
            CitraClient.Antennas,
            CitraClient.Satellites,
            CitraClient.Tasks,
            CitraClient.Weather
          ] do
        assert Code.ensure_loaded?(mod), "expected #{inspect(mod)} to be compiled"
      end
    end

    test "schema structs were generated" do
      for mod <- [
            CitraClient.Schemas.Antenna,
            CitraClient.Schemas.GroundStation,
            CitraClient.Schemas.Telescope
          ] do
        assert Code.ensure_loaded?(mod), "expected #{inspect(mod)} to be compiled"
        assert function_exported?(mod, :from_api, 1)
        assert function_exported?(mod, :to_api, 1)
      end
    end

    test "from_api coerces date-time fields to DateTime" do
      data = %{
        "id" => "00000000-0000-0000-0000-000000000000",
        "creationEpoch" => "2025-01-01T00:00:00Z"
      }

      struct = CitraClient.Schemas.Antenna.from_api(data)
      assert %DateTime{} = struct.creation_epoch
      assert struct.id == "00000000-0000-0000-0000-000000000000"
    end

    test "to_api encodes DateTime back to ISO8601 and uses camelCase keys" do
      {:ok, dt, _} = DateTime.from_iso8601("2025-01-01T00:00:00Z")

      struct = struct(CitraClient.Schemas.Antenna, id: "abc", creation_epoch: dt)
      api = CitraClient.Schemas.Antenna.to_api(struct)

      assert api["id"] == "abc"
      assert api["creationEpoch"] == "2025-01-01T00:00:00Z"
      refute Map.has_key?(api, "name")
    end
  end

  describe "name derivation" do
    alias CitraClient.OpenAPI

    test "operationId -> function name strips path+method suffix" do
      assert OpenAPI.function_name("list_antennas_antennas_get", "/antennas", "get") ==
               :list_antennas

      assert OpenAPI.function_name(
               "update_ground_station_ground_stations__ground_station_id__put",
               "/ground-stations/{ground_station_id}",
               "put"
             ) == :update_ground_station

      assert OpenAPI.function_name("solve_od_od__post", "/od/", "post") == :solve_od
    end

    test "snake_case handles camelCase and uppercase runs" do
      assert OpenAPI.snake_case("groundStationId") == "ground_station_id"
      assert OpenAPI.snake_case("AWSAccessKeyId") == "aws_access_key_id"
      assert OpenAPI.snake_case("id") == "id"
    end

    test "tag -> module and schema -> module" do
      assert OpenAPI.tag_module("ground_stations") == CitraClient.GroundStations
      assert OpenAPI.tag_module("caf-results") == CitraClient.CafResults
      assert OpenAPI.schema_module("Elset-Output") == CitraClient.Schemas.ElsetOutput
    end
  end

  describe "live API (requires CITRA_PAT)" do
    @describetag :live

    test "get_ground_stations returns a decoded result" do
      token = System.get_env("CITRA_PAT")

      if is_nil(token) or token == "" do
        flunk("CITRA_PAT must be set to run :live tests")
      end

      CitraClient.set_env(:dev)
      CitraClient.set_token(token)

      {:ok, result} = CitraClient.GroundStations.get_ground_stations()
      assert is_list(result) or is_map(result)
    end
  end
end
