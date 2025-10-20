defmodule CitraClient.Entities.Telescope do
  defstruct [
    :id,
    :user_id,
    :groundstation_id,
    :satellite_id,
    :creation_epoch,
    :last_connection_epoch,
    :name,
    :angular_noise,
    :field_of_view,
    :max_magnitude,
    :min_elevation,
    :max_slew_rate,
    :home_azimuth,
    :home_elevation
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          user_id: String.t(),
          groundstation_id: String.t(),
          satellite_id: String.t() | nil,
          creation_epoch: DateTime.t(),
          last_connection_epoch: DateTime.t() | nil,
          name: String.t(),
          angular_noise: float(),
          field_of_view: float(),
          max_magnitude: float(),
          min_elevation: float(),
          max_slew_rate: float(),
          home_azimuth: float(),
          home_elevation: float()
        }
end
