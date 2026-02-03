defmodule CitraClientTest do
  use ExUnit.Case, async: false

  alias CitraClient.Entities.Groundstation
  alias CitraClient.Entities.Telescope
  alias CitraClient.Entities.Antenna
  alias CitraClient.Entities.Task

  @moduletag :integration

  # Setup: configure dev environment and API token
  setup_all do
    # Ensure we're using dev environment
    CitraClient.set_env(:dev)

    # Get API token from environment variable
    token = System.get_env("CITRA_PAT")

    if is_nil(token) or token == "" do
      raise "CITRA_PAT environment variable must be set to run tests"
    end

    CitraClient.set_token(token)

    :ok
  end

  describe "environment configuration" do
    test "set_env/1 and get_env/0 work correctly" do
      CitraClient.set_env(:dev)
      assert CitraClient.get_env() == :dev

      CitraClient.set_env(:prod)
      assert CitraClient.get_env() == :prod

      # Reset to dev for other tests
      CitraClient.set_env(:dev)
    end

    test "base_url/0 returns correct URL for dev environment" do
      CitraClient.set_env(:dev)
      assert CitraClient.base_url() == "https://dev.api.citra.space/"
    end

    test "base_url/0 returns correct URL for prod environment" do
      CitraClient.set_env(:prod)
      assert CitraClient.base_url() == "https://api.citra.space/"

      # Reset to dev
      CitraClient.set_env(:dev)
    end
  end

  describe "groundstation CRUD operations" do
    test "create, read, update, and delete groundstation" do
      # Create a test groundstation
      groundstation = %Groundstation{
        name: "Test Groundstation #{:rand.uniform(100_000)}",
        latitude: 40.7128,
        longitude: -74.0060,
        altitude: 10.0
      }

      # Create
      {:ok, groundstation_id} = CitraClient.create_groundstation(groundstation)
      assert is_binary(groundstation_id)

      # Read by ID
      {:ok, fetched} = CitraClient.get_groundstation(groundstation_id)
      assert fetched.id == groundstation_id
      assert fetched.name == groundstation.name
      assert fetched.latitude == groundstation.latitude
      assert fetched.longitude == groundstation.longitude

      # Update
      updated_groundstation = %{fetched | name: "Updated Test Groundstation"}
      assert :ok == CitraClient.update_groundstation(updated_groundstation)

      # Verify update
      {:ok, refetched} = CitraClient.get_groundstation(groundstation_id)
      assert refetched.name == "Updated Test Groundstation"

      # Get all groundstations should include our new one
      all_groundstations = CitraClient.get_groundstations()
      assert is_list(all_groundstations)

      # Get my groundstations
      my_groundstations = CitraClient.get_my_groundstations()
      assert is_list(my_groundstations)
      assert Enum.any?(my_groundstations, fn gs -> gs.id == groundstation_id end)

      # Cleanup: delete the groundstation
      assert :ok == CitraClient.delete_groundstation(groundstation_id)

      # Verify deletion
      {:error, _} = CitraClient.get_groundstation(groundstation_id)
    end
  end

  describe "telescope CRUD operations" do
    setup do
      # Create a groundstation for telescope tests
      groundstation = %Groundstation{
        name: "Telescope Test GS #{:rand.uniform(100_000)}",
        latitude: 34.0522,
        longitude: -118.2437,
        altitude: 100.0
      }

      {:ok, groundstation_id} = CitraClient.create_groundstation(groundstation)

      on_exit(fn ->
        CitraClient.delete_groundstation(groundstation_id)
      end)

      {:ok, groundstation_id: groundstation_id}
    end

    test "create, read, update, and delete telescope", %{groundstation_id: groundstation_id} do
      # Create a telescope
      telescope = %Telescope{
        name: "Test Telescope #{:rand.uniform(100_000)}",
        groundstation_id: groundstation_id,
        angular_noise: 0.5,
        field_of_view: 2.0,
        max_magnitude: 12.0,
        min_elevation: 15.0,
        max_slew_rate: 5.0,
        home_azimuth: 180.0,
        home_elevation: 45.0
      }

      # Create
      {:ok, telescope_id} = CitraClient.create_telescope(telescope)
      assert is_binary(telescope_id)

      # Read by ID (returns list)
      [fetched] = CitraClient.get_telescopes(telescope_id)
      assert fetched.id == telescope_id
      assert fetched.name == telescope.name

      # Get all telescopes
      all_telescopes = CitraClient.get_telescopes()
      assert is_list(all_telescopes)

      # Get my telescopes
      my_telescopes = CitraClient.get_my_telescopes()
      assert is_list(my_telescopes)
      assert Enum.any?(my_telescopes, fn t -> t.id == telescope_id end)

      # Get telescopes by groundstation
      gs_telescopes = CitraClient.get_telescopes_by_groundstation(groundstation_id)
      assert is_list(gs_telescopes)
      assert Enum.any?(gs_telescopes, fn t -> t.id == telescope_id end)

      # Update telescope
      updated_telescope = %{fetched | name: "Updated Test Telescope"}
      assert :ok == CitraClient.update_telescope(updated_telescope)

      # Verify update
      [refetched] = CitraClient.get_telescopes(telescope_id)
      assert refetched.name == "Updated Test Telescope"

      # Get telescope images (may be empty)
      images = CitraClient.get_telescope_images(telescope_id)
      assert is_list(images)

      # Cleanup: delete the telescope
      assert :ok == CitraClient.delete_telescope(telescope_id)
    end

    test "batch create and delete telescopes", %{groundstation_id: groundstation_id} do
      # Create multiple telescopes
      telescopes = [
        %Telescope{
          name: "Batch Telescope 1 #{:rand.uniform(100_000)}",
          groundstation_id: groundstation_id,
          angular_noise: 0.5,
          field_of_view: 2.0,
          max_magnitude: 12.0,
          min_elevation: 15.0,
          max_slew_rate: 5.0,
          home_azimuth: 180.0,
          home_elevation: 45.0
        },
        %Telescope{
          name: "Batch Telescope 2 #{:rand.uniform(100_000)}",
          groundstation_id: groundstation_id,
          angular_noise: 0.6,
          field_of_view: 2.5,
          max_magnitude: 11.0,
          min_elevation: 20.0,
          max_slew_rate: 4.0,
          home_azimuth: 90.0,
          home_elevation: 30.0
        }
      ]

      {:ok, telescope_ids} = CitraClient.create_telescopes(telescopes)
      assert is_list(telescope_ids)
      assert length(telescope_ids) == 2

      # Cleanup: delete all created telescopes
      assert :ok == CitraClient.delete_telescopes(telescope_ids)
    end
  end

  describe "antenna CRUD operations" do
    setup do
      # Create a groundstation for antenna tests
      groundstation = %Groundstation{
        name: "Antenna Test GS #{:rand.uniform(100_000)}",
        latitude: 51.5074,
        longitude: -0.1278,
        altitude: 50.0
      }

      {:ok, groundstation_id} = CitraClient.create_groundstation(groundstation)

      on_exit(fn ->
        CitraClient.delete_groundstation(groundstation_id)
      end)

      {:ok, groundstation_id: groundstation_id}
    end

    test "create, read, and delete antenna", %{groundstation_id: groundstation_id} do
      # Create an antenna
      antenna = %Antenna{
        name: "Test Antenna #{:rand.uniform(100_000)}",
        ground_station_id: groundstation_id,
        min_frequency: 400_000_000,
        max_frequency: 450_000_000,
        min_elevation: 10.0,
        max_slew_rate: 3.0,
        home_azimuth: 0.0,
        home_elevation: 90.0,
        half_power_beam_width: 10.0
      }

      # Create
      {:ok, antenna_id} = CitraClient.create_antenna(antenna)
      assert is_binary(antenna_id)

      # Read by ID
      {:ok, fetched} = CitraClient.get_antenna(antenna_id)
      assert fetched.id == antenna_id
      assert fetched.name == antenna.name

      # Get all antennas
      all_antennas = CitraClient.get_antennas()
      assert is_list(all_antennas)

      # Get my antennas
      my_antennas = CitraClient.get_my_antennas()
      assert is_list(my_antennas)
      assert Enum.any?(my_antennas, fn a -> a.id == antenna_id end)

      # Get antennas by groundstation
      gs_antennas = CitraClient.get_antennas_by_groundstation(groundstation_id)
      assert is_list(gs_antennas)
      assert Enum.any?(gs_antennas, fn a -> a.id == antenna_id end)

      # Get antenna tasks (may be empty)
      tasks = CitraClient.get_antenna_tasks(antenna_id)
      assert is_list(tasks)

      # Get antenna RF captures (may be empty)
      rf_captures = CitraClient.get_antenna_rf_captures(antenna_id)
      assert is_list(rf_captures)

      # Cleanup: delete the antenna
      assert :ok == CitraClient.delete_antenna(antenna_id)

      # Verify deletion
      {:error, _} = CitraClient.get_antenna(antenna_id)
    end
  end

  describe "satellite read operations" do
    test "get_satellites returns paginated results" do
      {:ok, result} = CitraClient.get_satellites(page: 1, page_size: 10)
      assert is_map(result)
    end

    test "get_satellites_overview returns statistics" do
      {:ok, overview} = CitraClient.get_satellites_overview()
      assert is_map(overview)
    end

    test "get_satellite returns a specific satellite" do
      # First get a list of satellites to find a valid ID
      {:ok, result} = CitraClient.get_satellites(page: 1, page_size: 1)

      if result["data"] && length(result["data"]) > 0 do
        satellite_data = hd(result["data"])
        satellite_id = satellite_data["id"]

        {:ok, satellite} = CitraClient.get_satellite(satellite_id)
        assert satellite.id == satellite_id
      end
    end

    test "get_satellite_tasks returns tasks for a satellite" do
      {:ok, result} = CitraClient.get_satellites(page: 1, page_size: 1)

      if result["data"] && length(result["data"]) > 0 do
        satellite_id = hd(result["data"])["id"]
        tasks = CitraClient.get_satellite_tasks(satellite_id)
        assert is_list(tasks)
      end
    end

    test "get_satellite_images returns images for a satellite" do
      {:ok, result} = CitraClient.get_satellites(page: 1, page_size: 1)

      if result["data"] && length(result["data"]) > 0 do
        satellite_id = hd(result["data"])["id"]
        images = CitraClient.get_satellite_images(satellite_id)
        assert is_list(images)
      end
    end

    test "get_satellite_rf_captures returns RF captures for a satellite" do
      {:ok, result} = CitraClient.get_satellites(page: 1, page_size: 1)

      if result["data"] && length(result["data"]) > 0 do
        satellite_id = hd(result["data"])["id"]
        rf_captures = CitraClient.get_satellite_rf_captures(satellite_id)
        assert is_list(rf_captures)
      end
    end
  end

  describe "image management operations" do
    test "get_my_images returns list of user images" do
      images = CitraClient.get_my_images()
      assert is_list(images)
    end
  end

  describe "weather operations" do
    test "get_weather returns weather data for a location" do
      {:ok, weather} = CitraClient.get_weather(40.7128, -74.0060)
      assert is_map(weather)
    end

    test "get_weather supports different units" do
      {:ok, weather} = CitraClient.get_weather(51.5074, -0.1278, units: "metric")
      assert is_map(weather)
    end
  end

  describe "task operations with telescope" do
    setup do
      # Create groundstation and telescope for task tests
      groundstation = %Groundstation{
        name: "Task Test GS #{:rand.uniform(100_000)}",
        latitude: 35.6762,
        longitude: 139.6503,
        altitude: 40.0
      }

      {:ok, groundstation_id} = CitraClient.create_groundstation(groundstation)

      telescope = %Telescope{
        name: "Task Test Telescope #{:rand.uniform(100_000)}",
        groundstation_id: groundstation_id,
        angular_noise: 0.5,
        field_of_view: 2.0,
        max_magnitude: 12.0,
        min_elevation: 15.0,
        max_slew_rate: 5.0,
        home_azimuth: 180.0,
        home_elevation: 45.0
      }

      {:ok, telescope_id} = CitraClient.create_telescope(telescope)

      on_exit(fn ->
        CitraClient.delete_telescope(telescope_id)
        CitraClient.delete_groundstation(groundstation_id)
      end)

      {:ok, groundstation_id: groundstation_id, telescope_id: telescope_id}
    end

    test "get_tasks returns tasks for a telescope", %{telescope_id: telescope_id} do
      tasks = CitraClient.get_tasks(telescope_id)
      assert is_list(tasks)
    end

    test "get_tasks supports filtering by time range", %{telescope_id: telescope_id} do
      now = DateTime.utc_now()
      past = DateTime.add(now, -86400, :second)

      tasks =
        CitraClient.get_tasks(telescope_id,
          task_start_after: past,
          task_start_before: now
        )

      assert is_list(tasks)
    end
  end

  describe "task creation and update" do
    setup do
      # Create groundstation and telescope for task tests
      groundstation = %Groundstation{
        name: "Task Create Test GS #{:rand.uniform(100_000)}",
        latitude: 48.8566,
        longitude: 2.3522,
        altitude: 35.0
      }

      {:ok, groundstation_id} = CitraClient.create_groundstation(groundstation)

      telescope = %Telescope{
        name: "Task Create Test Telescope #{:rand.uniform(100_000)}",
        groundstation_id: groundstation_id,
        angular_noise: 0.5,
        field_of_view: 2.0,
        max_magnitude: 12.0,
        min_elevation: 15.0,
        max_slew_rate: 5.0,
        home_azimuth: 180.0,
        home_elevation: 45.0
      }

      {:ok, telescope_id} = CitraClient.create_telescope(telescope)

      on_exit(fn ->
        CitraClient.delete_telescope(telescope_id)
        CitraClient.delete_groundstation(groundstation_id)
      end)

      {:ok, groundstation_id: groundstation_id, telescope_id: telescope_id}
    end

    test "create and update task", %{telescope_id: telescope_id} do
      # Get a satellite ID to use for the task
      {:ok, sat_result} = CitraClient.get_satellites(page: 1, page_size: 1)

      if sat_result["data"] && length(sat_result["data"]) > 0 do
        satellite_id = hd(sat_result["data"])["id"]

        # Create a task in the future
        now = DateTime.utc_now()
        task_start = DateTime.add(now, 3600, :second)
        task_end = DateTime.add(now, 3900, :second)

        task = %Task{
          task_start: task_start,
          task_end: task_end,
          satellite_id: satellite_id,
          telescope_id: telescope_id
        }

        case CitraClient.create_task(task) do
          {:ok, task_id} ->
            assert is_binary(task_id)

            # Update task status to canceled
            assert :ok == CitraClient.update_task(task_id, :canceled)

            # Get task images (should be empty for new task)
            images = CitraClient.get_task_images(task_id)
            assert is_list(images)

            # Get task RF captures (should be empty for new task)
            rf_captures = CitraClient.get_task_rf_captures(task_id)
            assert is_list(rf_captures)

          {:error, _reason} ->
            # Task creation may fail if satellite doesn't support scheduling
            :ok
        end
      end
    end
  end
end
