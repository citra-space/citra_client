defmodule CitraClient.Entities.Groundstation do
  defstruct [
    :latitude,
    :longitude,
    :altitude,
    :id,
    :user_id,
    :creation_epoch,
    :update_epoch,
    :name
  ]

  @type t :: %__MODULE__{
          latitude: float(),
          longitude: float(),
          altitude: float(),
          id: String.t(),
          user_id: String.t(),
          creation_epoch: DateTime.t(),
          update_epoch: DateTime.t() | nil,
          name: String.t()
        }
end
