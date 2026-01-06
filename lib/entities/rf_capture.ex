defmodule CitraClient.Entities.RfCapture do
  defmodule Detection do
    defstruct [
      :center_frequency_hz,
      :bandwidth_hz,
      :strength_dbm,
      :snr_db
    ]

    @type t :: %__MODULE__{
            center_frequency_hz: pos_integer(),
            bandwidth_hz: pos_integer(),
            strength_dbm: float(),
            snr_db: float()
          }
  end

  defmodule PowerSpectralDensity do
    defstruct [
      :frequency_hz,
      :power_dbm_per_hz
    ]

    @type t :: %__MODULE__{
            frequency_hz: [integer()],
            power_dbm_per_hz: [float()]
          }
  end

  defmodule Data do
    defstruct [
      :detections,
      :power_spectral_density
    ]

    @type t :: %__MODULE__{
            detections: [Detection.t()],
            power_spectral_density: PowerSpectralDensity.t()
          }
  end

  defstruct [
    :antenna_id,
    :task_id,
    :data,
    :capture_start,
    :capture_end
  ]

  @type t :: %__MODULE__{
          antenna_id: String.t(),
          task_id: String.t() | nil,
          data: Data.t(),
          capture_start: DateTime.t(),
          capture_end: DateTime.t()
        }
end
