defmodule CitraClient.Entities.Antenna do
  defstruct [
    :id,
    :user_id,
    :ground_station_id,
    :satellite_id,
    :user_group_id,
    :creation_epoch,
    :username,
    :last_connection_epoch,
    :name,
    :min_frequency,
    :max_frequency,
    :min_elevation,
    :max_slew_rate,
    :home_azimuth,
    :home_elevation,
    :half_power_beam_width,
    :status
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          ground_station_id: String.t() | nil,
          satellite_id: String.t() | nil,
          user_group_id: String.t() | nil,
          creation_epoch: DateTime.t(),
          username: String.t() | nil,
          last_connection_epoch: DateTime.t() | nil,
          name: String.t(),
          min_frequency: integer(),
          max_frequency: integer(),
          min_elevation: float(),
          max_slew_rate: float(),
          home_azimuth: float(),
          home_elevation: float(),
          half_power_beam_width: float(),
          status: String.t()
        }
end
