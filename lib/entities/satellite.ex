defmodule CitraClient.Entities.Satellite do
  @moduledoc """
  Satellite entity representing a tracked space object
  """

  defstruct [
    :id,
    :name,
    :norad_id,
    :cospar_id,
    :object_type,
    :country,
    :launch_date,
    :decay_date,
    :period,
    :inclination,
    :apogee,
    :perigee,
    :rcs,
    :data_status,
    :orbit_center,
    :orbit_type
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t() | nil,
          norad_id: integer() | nil,
          cospar_id: String.t() | nil,
          object_type: String.t() | nil,
          country: String.t() | nil,
          launch_date: Date.t() | nil,
          decay_date: Date.t() | nil,
          period: float() | nil,
          inclination: float() | nil,
          apogee: float() | nil,
          perigee: float() | nil,
          rcs: float() | nil,
          data_status: String.t() | nil,
          orbit_center: String.t() | nil,
          orbit_type: String.t() | nil
        }
end

defmodule CitraClient.Entities.SatelliteSummary do
  @moduledoc """
  Summary satellite entity for list responses
  """

  defstruct [
    :id,
    :name,
    :norad_id,
    :cospar_id,
    :object_type,
    :country,
    :rcs,
    :inclination,
    :period,
    :apogee,
    :perigee
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t() | nil,
          norad_id: integer() | nil,
          cospar_id: String.t() | nil,
          object_type: String.t() | nil,
          country: String.t() | nil,
          rcs: float() | nil,
          inclination: float() | nil,
          period: float() | nil,
          apogee: float() | nil,
          perigee: float() | nil
        }
end
