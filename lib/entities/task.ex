defmodule CitraClient.Entities.Task do
  defstruct [
    :id,
    :task_start,
    :task_end,
    :satellite_id,
    :telescope_id,
    :antenna_id,
    :status
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          task_start: DateTime.t(),
          task_end: DateTime.t(),
          satellite_id: integer(),
          telescope_id: String.t() | nil,
          antenna_id: String.t() | nil,
          status: CitraClient.Entities.TaskStatus.t()
        }
end

# task status enum
defmodule CitraClient.Entities.TaskStatus do
  @type t :: :pending | :canceled | :scheduled | :succeeded | :failed

  def to_string(status) do
    case status do
      :pending -> "Pending"
      :canceled -> "Canceled"
      :scheduled -> "Scheduled"
      :succeeded -> "Succeeded"
      :failed -> "Failed"
    end
  end
end
